"""Real local Git integration tests. No studio/Play contact or real allocation."""
import concurrent.futures
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from android_counter import CounterError, Ledger, MAX_VERSION_CODE, PendingBaseline, TRUSTED_LEDGER_CONFIG


APPLICATION = "com.pallobbygames.counterfixture"
MODULE_DIRECTORY = str(Path(__file__).resolve().parents[1])


def git(directory, *args):
    result = subprocess.run(["git", "-c", "core.hooksPath=", "-C", str(directory), *args],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return result.stdout.strip()


def fixture_state(floor=42):
    return {"schema": 1, "application_id": APPLICATION,
            "baseline": {"verified": True, "all_play_tracks_and_history_reviewed": True,
                         "retained_assignments_reviewed": True, "max_used_code": floor,
                         "evidence": ["Synthetic fixture only: all test tracks/history/assignments reviewed"]},
            "last_code": floor, "allocations": {}}


def reserve_subprocess(remote, request_id):
    code = ("import sys,json;sys.path.insert(0,sys.argv[1]);from android_counter import Ledger;"
            "print(json.dumps(Ledger(remote=sys.argv[2],attempts=30).reserve(sys.argv[3],sys.argv[4])))")
    result = subprocess.run([sys.executable, "-c", code, MODULE_DIRECTORY, remote, APPLICATION, request_id],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
    if result.returncode:
        raise AssertionError(result.stderr)
    return json.loads(result.stdout)


def bind_subprocess(remote, checksum):
    code = ("import sys,json;sys.path.insert(0,sys.argv[1]);from android_counter import Ledger;"
            "print(json.dumps(Ledger(remote=sys.argv[2],attempts=30).bind_artifact("
            "sys.argv[3],'binding',43,sha256=sys.argv[4],version='1.2.3-rc.1',commit='a'*40)))")
    result = subprocess.run([sys.executable, "-c", code, MODULE_DIRECTORY, remote, APPLICATION, checksum],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
    return result.returncode, json.loads(result.stdout) if result.stdout else None, result.stderr


class CounterTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="plg-counter-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.remote = self.root / "ledger.git"
        self.admin = self.root / "admin"
        self.remote.mkdir()
        git(self.remote, "init", "--bare")
        self.admin.mkdir()
        git(self.admin, "init", "-b", TRUSTED_LEDGER_CONFIG["branch"])
        git(self.admin, "config", "user.name", "Counter tests")
        git(self.admin, "config", "user.email", "counter-test@example.invalid")
        git(self.admin, "config", "commit.gpgSign", "false")
        git(self.admin, "remote", "add", "origin", str(self.remote))
        self.ledger = Ledger(remote=str(self.remote), attempts=30)

    def seed(self, state=None):
        path = self.admin / "applications" / f"{APPLICATION}.json"
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(fixture_state() if state is None else state), encoding="utf-8")
        git(self.admin, "add", ".")
        git(self.admin, "commit", "-m", "Reviewed synthetic baseline")
        git(self.admin, "push", "origin", f"HEAD:refs/heads/{self.ledger.branch}")

    def head(self):
        return git(self.remote, "rev-parse", f"refs/heads/{self.ledger.branch}")

    def test_absent_branch_is_inspectable_and_never_initialized(self):
        result = self.ledger.inspect(APPLICATION)
        self.assertEqual(result["status"], "pending")
        with self.assertRaises(PendingBaseline):
            self.ledger.reserve(APPLICATION, "new-build")
        self.assertEqual(subprocess.run(["git", "-C", str(self.remote), "show-ref", "--heads"],
                                        capture_output=True, text=True).stdout, "")

    def test_missing_application_does_not_guess_a_floor(self):
        self.seed()
        initial = self.head()
        self.assertEqual(self.ledger.inspect("com.example.other")["status"], "pending")
        with self.assertRaises(PendingBaseline):
            self.ledger.reserve("com.example.other", "other")
        self.assertEqual(self.head(), initial)

    def test_tag_cannot_substitute_for_authoritative_branch(self):
        self.seed()
        git(self.admin, "tag", self.ledger.branch, "HEAD")
        git(self.admin, "push", "origin", f"refs/tags/{self.ledger.branch}")
        git(self.admin, "push", "origin", f":refs/heads/{self.ledger.branch}")
        self.assertEqual(self.ledger.inspect(APPLICATION)["status"], "pending")
        with self.assertRaises(PendingBaseline):
            self.ledger.reserve(APPLICATION, "must-not-create-branch")

    def test_reservation_idempotence_and_remote_validation(self):
        self.seed()
        first = self.ledger.reserve(APPLICATION, "repo:workflow:attempt")
        initial = self.head()
        again = self.ledger.reserve(APPLICATION, "repo:workflow:attempt")
        self.assertEqual(first["version_code"], 43)
        self.assertEqual(again["version_code"], 43)
        self.assertTrue(again["reused"])
        self.assertEqual(self.head(), initial)
        self.assertEqual(self.ledger.validate_reservation(APPLICATION, "repo:workflow:attempt", 43)["version_code"], 43)
        with self.assertRaises(CounterError):
            self.ledger.validate_reservation(APPLICATION, "repo:workflow:attempt", 44)
        with self.assertRaises(CounterError):
            self.ledger.validate_reservation(APPLICATION, "unreserved", 43)

    def test_dry_run_and_inspection_do_not_create_commits(self):
        self.seed()
        initial = self.head()
        result = self.ledger.reserve(APPLICATION, "preview", dry_run=True)
        self.assertIsNone(result["version_code"])
        self.assertEqual(result["next_version_code"], 43)
        self.assertEqual(self.ledger.inspect(APPLICATION, "preview")["status"], "ready")
        self.assertEqual(self.head(), initial)

    def test_dry_run_existing_request_is_read_only(self):
        self.seed()
        self.ledger.reserve(APPLICATION, "existing")
        initial = self.head()
        result = self.ledger.reserve(APPLICATION, "existing", dry_run=True)
        self.assertIsNone(result["version_code"])
        self.assertEqual(result["reserved_version_code"], 43)
        self.assertEqual(self.head(), initial)

    def test_parallel_new_artifacts_have_unique_monotonic_codes(self):
        self.seed()
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            results = list(executor.map(lambda number: reserve_subprocess(str(self.remote), f"new-{number}"), range(6)))
        self.assertEqual(sorted(result["version_code"] for result in results), list(range(43, 49)))
        self.assertEqual(self.ledger.inspect(APPLICATION)["last_code"], 48)

    def test_parallel_retries_of_same_artifact_only_reserve_once(self):
        self.seed()
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            results = list(executor.map(lambda _: reserve_subprocess(str(self.remote), "same-artifact"), range(5)))
        self.assertEqual({result["version_code"] for result in results}, {43})
        self.assertEqual(git(self.remote, "rev-list", "--count", self.head()), "2")

    def test_cap_is_enforced_and_existing_request_still_reusable(self):
        self.seed(fixture_state(MAX_VERSION_CODE - 1))
        self.assertEqual(self.ledger.reserve(APPLICATION, "last")["version_code"], MAX_VERSION_CODE)
        initial = self.head()
        with self.assertRaises(CounterError):
            self.ledger.reserve(APPLICATION, "overflow")
        self.assertEqual(self.ledger.reserve(APPLICATION, "last")["version_code"], MAX_VERSION_CODE)
        self.assertIsNone(self.ledger.inspect(APPLICATION)["next_version_code"])
        self.assertEqual(self.head(), initial)

    def test_unverified_baseline_blocks_allocation(self):
        state = fixture_state()
        state["baseline"]["all_play_tracks_and_history_reviewed"] = False
        self.seed(state)
        self.assertEqual(self.ledger.inspect(APPLICATION)["status"], "pending")
        with self.assertRaises(PendingBaseline):
            self.ledger.reserve(APPLICATION, "blocked")

    def test_corrupt_high_water_mark_blocks_allocation(self):
        state = fixture_state()
        state["last_code"] += 1
        self.seed(state)
        with self.assertRaises(CounterError):
            self.ledger.reserve(APPLICATION, "blocked")

    def test_invalid_identifier_and_placeholder_evidence_are_rejected(self):
        with self.assertRaises(CounterError):
            self.ledger.reserve("../traversal", "id")
        state = fixture_state()
        state["baseline"]["evidence"] = ["<pending evidence>"]
        self.seed(state)
        with self.assertRaises(PendingBaseline):
            self.ledger.reserve(APPLICATION, "id")

    def test_ambiguous_success_is_reconciled_using_persisted_request_id(self):
        self.seed()

        class LostResponseLedger(Ledger):
            def _git(inner_self, directory, *args, **kwargs):
                result = super()._git(directory, *args, **kwargs)
                if args and args[0] == "push" and result.returncode == 0:
                    raise CounterError("Synthetic lost response after successful push")
                return result

        result = LostResponseLedger(remote=str(self.remote), attempts=1).reserve(APPLICATION, "uncertain")
        self.assertEqual(result["version_code"], 43)
        self.assertEqual(self.ledger.reserve(APPLICATION, "uncertain")["version_code"], 43)
        self.assertEqual(git(self.remote, "rev-list", "--count", self.head()), "2")

    def test_rejected_push_has_bounded_retries_and_no_remote_allocation(self):
        self.seed()
        initial = self.head()

        class RejectPushLedger(Ledger):
            pushes = 0

            def _git(inner_self, directory, *args, **kwargs):
                if args and args[0] == "push":
                    inner_self.pushes += 1
                    return subprocess.CompletedProcess([], 1, "", "Synthetic rejected push")
                return super()._git(directory, *args, **kwargs)

        ledger = RejectPushLedger(remote=str(self.remote), attempts=2)
        with self.assertRaises(CounterError):
            ledger.reserve(APPLICATION, "same-request-next-time")
        self.assertEqual(ledger.pushes, 2)
        self.assertEqual(self.head(), initial)
        self.assertEqual(self.ledger.reserve(APPLICATION, "same-request-next-time")["version_code"], 43)

    def test_duplicate_json_keys_are_rejected(self):
        self.seed()
        path = self.admin / "applications" / f"{APPLICATION}.json"
        original = path.read_text(encoding="utf-8")
        path.write_text(original[:-1] + ', "last_code": 42}', encoding="utf-8")
        git(self.admin, "add", ".")
        git(self.admin, "commit", "-m", "Synthetic corrupt duplicate")
        git(self.admin, "push", "origin", f"HEAD:refs/heads/{self.ledger.branch}")
        with self.assertRaises(CounterError):
            self.ledger.reserve(APPLICATION, "blocked")

    def test_deleted_branch_during_push_is_not_recreated(self):
        self.seed()
        remote, ref = self.remote, f"refs/heads/{self.ledger.branch}"

        class DeleteBeforePush(Ledger):
            mutated = False

            def _git(inner_self, directory, *args, **kwargs):
                if args and args[0] == "push" and not inner_self.mutated:
                    inner_self.mutated = True
                    git(remote, "update-ref", "-d", ref)
                return super()._git(directory, *args, **kwargs)

        with self.assertRaises(CounterError):
            DeleteBeforePush(remote=str(remote)).reserve(APPLICATION, "deleted-race")
        result = subprocess.run(["git", "-C", str(remote), "show-ref", "--verify", ref], capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_rewound_branch_during_push_is_not_accepted_or_retried_from_lower_state(self):
        self.seed()
        baseline = self.head()
        self.ledger.reserve(APPLICATION, "already-assigned")
        remote, ref = self.remote, f"refs/heads/{self.ledger.branch}"

        class RewindBeforePush(Ledger):
            mutated = False

            def _git(inner_self, directory, *args, **kwargs):
                if args and args[0] == "push" and not inner_self.mutated:
                    inner_self.mutated = True
                    git(remote, "update-ref", ref, baseline)
                return super()._git(directory, *args, **kwargs)

        with self.assertRaises(CounterError):
            RewindBeforePush(remote=str(remote)).reserve(APPLICATION, "rewind-race")
        self.assertEqual(self.head(), baseline)

    def test_rewind_between_advertisement_and_clone_is_rejected(self):
        self.seed()
        baseline = self.head()
        self.ledger.reserve(APPLICATION, "already-assigned")
        remote, ref = self.remote, f"refs/heads/{self.ledger.branch}"

        class RewindBeforeClone(Ledger):
            def _git(inner_self, directory, *args, **kwargs):
                if args and args[0] == "clone":
                    git(remote, "update-ref", ref, baseline)
                return super()._git(directory, *args, **kwargs)

        with self.assertRaises(CounterError):
            RewindBeforeClone(remote=str(remote)).reserve(APPLICATION, "preclone-rewind")
        self.assertEqual(self.head(), baseline)

    def test_binding_is_idempotent_and_exact_bytes_version_commit_are_required(self):
        self.seed()
        self.ledger.reserve(APPLICATION, "binding")
        artifact = {"sha256": "1" * 64, "version": "1.2.3-rc.1", "commit": "a" * 40}
        bound = self.ledger.bind_artifact(APPLICATION, "binding", 43, **artifact)
        initial = self.head()
        self.assertEqual(bound["artifact"], artifact)
        self.assertTrue(bound["artifact_bound"])
        self.assertEqual(self.ledger.bind_artifact(APPLICATION, "binding", 43, **artifact)["artifact"], artifact)
        self.assertEqual(self.ledger.validate_reservation(APPLICATION, "binding", 43, **artifact)["artifact"], artifact)
        self.assertEqual(self.head(), initial)
        for key, changed in (("sha256", "2" * 64), ("version", "1.2.3"), ("commit", "b" * 40)):
            wrong = {**artifact, key: changed}
            with self.assertRaises(CounterError):
                self.ledger.bind_artifact(APPLICATION, "binding", 43, **wrong)
            with self.assertRaises(CounterError):
                self.ledger.validate_reservation(APPLICATION, "binding", 43, **wrong)
        with self.assertRaises(CounterError):
            self.ledger.bind_artifact(APPLICATION + ".dev", "binding", 43, **artifact)
        with self.assertRaises(CounterError):
            self.ledger.bind_artifact(APPLICATION, "binding", 44, **artifact)
        self.assertEqual(self.head(), initial)

    def test_unbound_reservation_is_ineligible_for_artifact_validation(self):
        self.seed()
        self.ledger.reserve(APPLICATION, "binding")
        with self.assertRaises(CounterError):
            self.ledger.validate_reservation(APPLICATION, "binding", 43, sha256="1" * 64, version="1.0.0", commit="a" * 40)

    def test_dry_run_binding_does_not_write_artifact(self):
        self.seed()
        self.ledger.reserve(APPLICATION, "binding")
        initial = self.head()
        result = self.ledger.bind_artifact(APPLICATION, "binding", 43, sha256="1" * 64,
                                          version="1.0.0", commit="a" * 40, dry_run=True)
        self.assertEqual(result["status"], "dry-run")
        self.assertFalse(result["artifact_bound"])
        self.assertEqual(self.head(), initial)
        self.assertFalse(self.ledger.inspect(APPLICATION, "binding")["artifact_bound"])

    def test_parallel_different_artifacts_only_one_binding_wins(self):
        self.seed()
        self.ledger.reserve(APPLICATION, "binding")
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            results = list(executor.map(lambda number: bind_subprocess(str(self.remote), f"{number:064x}"), range(5)))
        successes = [receipt for code, receipt, _ in results if code == 0]
        self.assertEqual(len(successes), 1, results)
        self.assertEqual(self.ledger.inspect(APPLICATION, "binding")["artifact"], successes[0]["artifact"])
        self.assertEqual(git(self.remote, "rev-list", "--count", self.head()), "3")

    def test_parallel_identical_artifacts_only_create_one_binding_commit(self):
        self.seed()
        self.ledger.reserve(APPLICATION, "binding")
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            results = list(executor.map(lambda _: bind_subprocess(str(self.remote), "1" * 64), range(5)))
        self.assertTrue(all(code == 0 for code, _, _ in results), results)
        self.assertEqual(git(self.remote, "rev-list", "--count", self.head()), "3")


if __name__ == "__main__":
    unittest.main()
