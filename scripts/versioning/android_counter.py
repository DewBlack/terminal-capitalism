#!/usr/bin/env python3
"""Coordinated Android assignments, backed by a trusted Git ref.

The versioned configuration below is shared by every publisher. There is no CLI
remote override or local-counter fallback. Ledger(remote=...) exists solely for
isolated test fixtures; publication must use Ledger() and the CLI.

Ledger bootstrap is deliberately a reviewed administrative change, never an
automatic guess from presets or a workflow number. See BASELINE_SCHEMA below.
No real ledger/ref is created by installing or testing this module.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).parent / "vendor"))
from semver import Version


TRUSTED_LEDGER_CONFIG = {
    "remote": "https://github.com/pallobbygames/studio.git",
    "branch": "android-version-ledger",
}
MAX_VERSION_CODE = 2_100_000_000
BASELINE_SCHEMA = {
    "schema": 1,
    "application_id": "<published applicationId>",
    "baseline": {
        "verified": True,
        "all_play_tracks_and_history_reviewed": True,
        "retained_assignments_reviewed": True,
        "max_used_code": "<integer including uploaded AND retained assigned codes>",
        "evidence": ["<dated evidence covering all tracks/history and local assignments>"],
    },
    "last_code": "<same integer initially>",
    "allocations": {},
}


class CounterError(RuntimeError):
    """Fail closed while retaining a reusable request ID."""


class PendingBaseline(CounterError):
    pass


def _application_id(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", value):
        raise CounterError("application-id inválido: usa el identificador Android publicado.")
    return value


def _request_id(value: str) -> str:
    if not isinstance(value, str) or not 1 <= len(value) <= 240 or any(ord(c) < 32 for c in value):
        raise CounterError("request-id debe tener 1–240 caracteres sin controles; consérvalo para reintentar.")
    return value


def _integer(value: object, minimum: int = 0) -> bool:
    return type(value) is int and minimum <= value <= MAX_VERSION_CODE


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def _artifact(sha256: str, version: str, commit: str) -> dict:
    if not isinstance(sha256, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", sha256):
        raise CounterError("sha256 debe ser el checksum SHA-256 completo de los bytes finales del artefacto.")
    if not isinstance(commit, str) or not re.fullmatch(r"(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})", commit):
        raise CounterError("commit debe ser el SHA completo del código construido.")
    try:
        if not isinstance(version, str):
            raise ValueError("Missing version")
        Version.parse(version)
    except ValueError as error:
        raise CounterError("version debe ser la versión SemVer efectiva del artefacto.") from error
    return {"sha256": sha256.lower(), "version": version, "commit": commit.lower()}


def _validate_state(state: object, application_id: str) -> dict:
    if not isinstance(state, dict) or type(state.get("schema")) is not int or state.get("schema") != 1 or state.get("application_id") != application_id:
        raise CounterError("Ledger inválido: schema/application_id no coinciden; requiere revisión administrativa.")
    baseline = state.get("baseline")
    if not isinstance(baseline, dict) or any(baseline.get(key) is not True for key in (
        "verified", "all_play_tracks_and_history_reviewed", "retained_assignments_reviewed"
    )):
        raise PendingBaseline("Baseline pendiente: revisar todos los canales e historial de Play y códigos asignados conservados.")
    evidence = baseline.get("evidence")
    floor = baseline.get("max_used_code")
    if not _integer(floor) or not isinstance(evidence, list) or not evidence or any(
        not isinstance(item, str) or not item.strip() or item.strip().startswith("<") for item in evidence
    ):
        raise PendingBaseline("Baseline sin máximo/evidencia verificable; no se puede inferir desde presets o runners.")
    allocations = state.get("allocations")
    if not isinstance(allocations, dict) or not _integer(state.get("last_code")):
        raise CounterError("Ledger inválido: faltan last_code/allocations.")
    codes = []
    for request_id, allocation in allocations.items():
        _request_id(request_id)
        if not isinstance(allocation, dict) or not _integer(allocation.get("version_code"), 1):
            raise CounterError("Ledger inválido: reserva sin código válido.")
        code = allocation["version_code"]
        if code <= floor or not isinstance(allocation.get("created_at"), str) or not allocation["created_at"]:
            raise CounterError("Ledger inválido: reserva anterior al baseline o sin fecha.")
        if "artifact" in allocation:
            artifact = allocation["artifact"]
            if not isinstance(artifact, dict) or set(artifact) != {"sha256", "version", "commit"} or _artifact(**artifact) != artifact:
                raise CounterError("Ledger inválido: identidad de artefacto no canónica.")
        codes.append(code)
    if len(set(codes)) != len(codes) or state["last_code"] != max([floor, *codes]):
        raise CounterError("Ledger inconsistente: códigos duplicados o last_code no coincide con el máximo conservado.")
    return state


class Ledger:
    """A temporary Git clone per operation; never modifies the caller's checkout."""

    def __init__(self, *, remote: str | None = None, attempts: int = 12):
        # remote is an API-only fixture seam. It must not be exposed by publishers.
        self.remote = remote if remote is not None else TRUSTED_LEDGER_CONFIG["remote"]
        self.branch = TRUSTED_LEDGER_CONFIG["branch"]
        if not 1 <= attempts <= 100:
            raise CounterError("El límite de reintentos debe estar entre 1 y 100.")
        self.attempts = attempts

    def _git(self, directory: Path | None, *args: str, input: str | None = None, check: bool = True):
        command = ["git", "-c", "core.hooksPath=", "-c", "commit.gpgSign=false"]
        if directory is not None:
            command += ["-C", str(directory)]
        try:
            result = subprocess.run(command + list(args), input=input, text=True, encoding="utf-8",
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise CounterError("Git no disponible o timeout. Conserva request-id y reintenta; no generes otro artefacto.") from error
        if check and result.returncode:
            raise CounterError("No se pudo consultar/actualizar el ledger. Verifica acceso Git a studio y conserva request-id.")
        return result

    @contextmanager
    def _clone(self):
        # --branch can also select a tag. Require a real authoritative branch;
        # a same-named tag must never bootstrap a missing allocator ref.
        probe = self._git(None, "ls-remote", "--exit-code", "--heads", self.remote,
                          f"refs/heads/{self.branch}", check=False)
        if probe.returncode == 2:
            raise PendingBaseline(
                "Falta la rama autoritativa android-version-ledger en studio. Un responsable debe revisar "
                "todos los canales/historial de Play y reservas conservadas, y registrar un baseline con evidencia; "
                "esta herramienta no inicializa códigos."
            )
        if probe.returncode:
            raise CounterError("No se pudo consultar el ledger autoritativo; verifica red/permisos. No hay fallback local.")
        advertised = probe.stdout.split()[0]
        with tempfile.TemporaryDirectory(prefix="plg-android-ledger-") as temporary:
            directory = Path(temporary) / "ledger"
            clone = self._git(None, "clone", "--no-checkout", "--no-tags", "--single-branch",
                              "--branch", self.branch, "--", self.remote, str(directory), check=False)
            if clone.returncode:
                probe = self._git(None, "ls-remote", "--exit-code", "--heads", self.remote,
                                  f"refs/heads/{self.branch}", check=False)
                if probe.returncode == 2:
                    raise PendingBaseline(
                        "Falta la rama autoritativa android-version-ledger en studio. Un responsable debe revisar "
                        "todos los canales/historial de Play y reservas conservadas, y registrar un baseline con evidencia; "
                        "esta herramienta no inicializa códigos."
                    )
                raise CounterError("No se pudo clonar el ledger autoritativo; verifica red/permisos. No hay fallback local.")
            # Full single-branch history lets us detect a rewind between the
            # advertised ref and clone, as well as between later read/write steps.
            tracking = self._git(directory, "show-ref", "--verify", f"refs/remotes/origin/{self.branch}", check=False)
            if tracking.returncode or self._git(directory, "merge-base", "--is-ancestor", advertised, "HEAD", check=False).returncode:
                raise CounterError("La rama autoritativa desapareció o retrocedió al clonar; detén la publicación y revisa el ledger.")
            yield directory

    def _read(self, directory: Path, application_id: str, *, refresh: bool = False, previous_sha: str | None = None):
        if refresh:
            self._git(directory, "fetch", "--no-tags", "origin", f"refs/heads/{self.branch}")
            sha = self._git(directory, "rev-parse", "FETCH_HEAD").stdout.strip()
        else:
            sha = self._git(directory, "rev-parse", "HEAD").stdout.strip()
        if previous_sha is not None and self._git(directory, "merge-base", "--is-ancestor", previous_sha, sha, check=False).returncode:
            raise CounterError("El ledger autoritativo retrocedió o cambió de historia durante la operación. "
                               "Detén la publicación y restaura/revisa el historial; no se recreará ni sobrescribirá la rama.")
        path = f"applications/{application_id}.json"
        raw = self._git(directory, "show", f"{sha}:{path}", check=False)
        if raw.returncode:
            raise PendingBaseline(f"Falta baseline para {application_id}: revisar Play completo y reservas conservadas; "
                                  f"añadir {path} mediante revisión administrativa en studio/{self.branch}.")
        try:
            state = json.loads(raw.stdout, object_pairs_hook=_unique_object)
        except (ValueError, TypeError) as error:
            raise CounterError(f"Ledger JSON inválido para {application_id}; requiere revisión administrativa.") from error
        return sha, path, _validate_state(state, application_id)

    @staticmethod
    def _receipt(application_id, request_id, code, sha, *, reused=False, artifact=None):
        result = {"status": "reserved", "application_id": application_id, "request_id": request_id,
                  "version_code": code, "ledger_commit": sha, "reused": reused, "artifact_bound": artifact is not None}
        if artifact is not None:
            result["artifact"] = artifact
        return result

    def _write(self, directory: Path, sha: str, path: str, state: dict, message: str):
        # Plumbing avoids checking out/executing any remote files/hooks.
        blob = self._git(directory, "hash-object", "-w", "--stdin",
                         input=json.dumps(state, ensure_ascii=False, sort_keys=True, indent=2) + "\n").stdout.strip()
        self._git(directory, "read-tree", sha)
        self._git(directory, "update-index", "--add", "--cacheinfo", f"100644,{blob},{path}")
        tree = self._git(directory, "write-tree").stdout.strip()
        commit = self._git(directory, "-c", "user.name=Pal Lobby Games version allocator", "-c",
                           "user.email=versioning@pallobbygames.invalid", "commit-tree", tree, "-p", sha,
                           input=message + "\n").stdout.strip()
        parents = [line for line in self._git(directory, "cat-file", "-p", commit).stdout.splitlines() if line.startswith("parent ")]
        if parents != [f"parent {sha}"]:
            raise CounterError("Commit de ledger inválido: debe ser hijo inmediato único de la revisión leída.")
        ref = f"refs/heads/{self.branch}"
        try:
            # The exact expected ref is an atomic compare-and-swap. Plain FF
            # push could recreate a deleted branch or accept an intervening rewind.
            # The parent invariant above ensures this lease can NEVER rewrite history.
            pushed = self._git(directory, "push", "--porcelain", f"--force-with-lease={ref}:{sha}",
                               "origin", f"{commit}:{ref}", check=False)
        except CounterError:
            pushed = None  # A timeout may follow a successful server update.
        return commit if pushed is not None and pushed.returncode == 0 else None

    def inspect(self, application_id: str, request_id: str | None = None) -> dict:
        application_id = _application_id(application_id)
        if request_id is not None:
            _request_id(request_id)
        try:
            with self._clone() as directory:
                sha, _, state = self._read(directory, application_id)
                if request_id in state["allocations"]:
                    allocation = state["allocations"][request_id]
                    return self._receipt(application_id, request_id, allocation["version_code"], sha,
                                         reused=True, artifact=allocation.get("artifact"))
                return {"status": "ready", "application_id": application_id, "last_code": state["last_code"],
                        "next_version_code": state["last_code"] + 1 if state["last_code"] < MAX_VERSION_CODE else None,
                        "ledger_commit": sha, "request_id": request_id}
        except PendingBaseline as error:
            return {"status": "pending", "application_id": application_id, "reason": str(error)}

    def reserve(self, application_id: str, request_id: str, *, dry_run: bool = False) -> dict:
        application_id, request_id = _application_id(application_id), _request_id(request_id)
        with self._clone() as directory:
            observed_sha = None
            for attempt in range(self.attempts):
                sha, path, state = self._read(directory, application_id, refresh=attempt > 0, previous_sha=observed_sha)
                observed_sha = sha
                allocation = state["allocations"].get(request_id)
                if allocation:
                    result = self._receipt(application_id, request_id, allocation["version_code"], sha,
                                           reused=True, artifact=allocation.get("artifact"))
                    if dry_run:
                        result["status"] = "dry-run"
                        result["reserved_version_code"] = result["version_code"]
                        result["version_code"] = None
                    return result
                if state["last_code"] >= MAX_VERSION_CODE:
                    raise CounterError("Contador agotado: Google Play limita versionCode a 2100000000; requiere decisión de producto.")
                code = state["last_code"] + 1
                if dry_run:
                    return {"status": "dry-run", "application_id": application_id, "request_id": request_id,
                            "version_code": None, "next_version_code": code, "ledger_commit": sha}
                state["last_code"] = code
                state["allocations"][request_id] = {
                    "version_code": code, "created_at": datetime.now(timezone.utc).isoformat()
                }
                commit = self._write(directory, sha, path, state, f"Reserve Android code for {application_id}")
                if commit is not None:
                    return self._receipt(application_id, request_id, code, commit)
                # Re-read after EVERY failed/ambiguous push, including final retry.
                # A server can accept the commit while the client loses its response.
                confirmed_sha, _, confirmed = self._read(directory, application_id, refresh=True, previous_sha=sha)
                observed_sha = confirmed_sha
                if request_id in confirmed["allocations"]:
                    return self._receipt(application_id, request_id,
                                         confirmed["allocations"][request_id]["version_code"], confirmed_sha,
                                         reused=True, artifact=confirmed["allocations"][request_id].get("artifact"))
                if attempt + 1 < self.attempts:
                    time.sleep(min(0.05 * (attempt + 1), 0.3))
            raise CounterError("No se confirmó la reserva tras conflictos/reintentos. Conserva request-id y vuelve a consultar; "
                               "no construyas ni asignes otro código desde un contador local.")

    def bind_artifact(self, application_id: str, request_id: str, version_code: int, *,
                      sha256: str, version: str, commit: str, dry_run: bool = False) -> dict:
        application_id, request_id = _application_id(application_id), _request_id(request_id)
        artifact = _artifact(sha256, version, commit)
        if not _integer(version_code, 1):
            raise CounterError("version-code inválido para vincular el artefacto.")
        with self._clone() as directory:
            observed_sha = None
            for attempt in range(self.attempts):
                sha, path, state = self._read(directory, application_id, refresh=attempt > 0, previous_sha=observed_sha)
                allocation = state["allocations"].get(request_id)
                if not allocation or allocation["version_code"] != version_code:
                    raise CounterError("No existe reserva exacta para application-id/request-id/version-code; no vincules ni publiques.")
                existing = allocation.get("artifact")
                if existing is not None and existing != artifact:
                    raise CounterError("La reserva ya está vinculada a otros bytes/versión/commit. "
                                       "Para un artefacto nuevo reserva con un request-id nuevo; nunca reutilices el código.")
                if existing is not None or dry_run:
                    result = self._receipt(application_id, request_id, version_code, sha, reused=True, artifact=existing)
                    if dry_run:
                        result["status"] = "dry-run"
                    return result
                allocation["artifact"] = artifact
                committed = self._write(directory, sha, path, state, f"Bind Android artifact for {application_id}")
                if committed is not None:
                    return self._receipt(application_id, request_id, version_code, committed, artifact=artifact)
                confirmed_sha, _, confirmed = self._read(directory, application_id, refresh=True, previous_sha=sha)
                observed_sha = confirmed_sha
                confirmed_allocation = confirmed["allocations"].get(request_id)
                if not confirmed_allocation or confirmed_allocation["version_code"] != version_code:
                    raise CounterError("La reserva desapareció o cambió durante la vinculación; detén la publicación y revisa el ledger.")
                bound = confirmed_allocation.get("artifact")
                if bound is not None:
                    if bound != artifact:
                        raise CounterError("Otro artefacto ganó la vinculación concurrente; reserva un código nuevo para estos bytes.")
                    return self._receipt(application_id, request_id, version_code, confirmed_sha, reused=True, artifact=bound)
                if attempt + 1 < self.attempts:
                    time.sleep(min(0.05 * (attempt + 1), 0.3))
            raise CounterError("Vinculación no confirmada. Conserva los bytes y request-id; consulta/reintenta sin regenerar el artefacto.")

    def validate_reservation(self, application_id: str, request_id: str, version_code: int, *,
                             sha256: str | None = None, version: str | None = None, commit: str | None = None) -> dict:
        result = self.inspect(application_id, request_id)
        if result["status"] != "reserved" or not _integer(version_code, 1) or result["version_code"] != version_code:
            raise CounterError("Reserva no confirmada para application-id/request-id/version-code. "
                               "Consulta el ledger con el mismo request-id; no publiques el artefacto.")
        if any(item is not None for item in (sha256, version, commit)):
            expected = _artifact(sha256, version, commit)
            if result.get("artifact") != expected:
                raise CounterError("Los bytes/versión/commit no coinciden con el artefacto vinculado en el ledger; no publiques.")
        return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Contador Android coordinado en el ledger Git autoritativo del estudio.")
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("inspect", "reserve", "bind-artifact", "validate-reservation"):
        command = commands.add_parser(name)
        command.add_argument("--application-id", required=True)
        command.add_argument("--request-id", required=name != "inspect")
        if name in ("reserve", "bind-artifact"):
            command.add_argument("--dry-run", action="store_true")
        if name in ("validate-reservation", "bind-artifact"):
            command.add_argument("--version-code", type=int, required=True)
            command.add_argument("--sha256", required=name == "bind-artifact")
            command.add_argument("--version", required=name == "bind-artifact")
            command.add_argument("--commit", required=name == "bind-artifact")
    args = parser.parse_args(argv)
    try:
        ledger = Ledger()
        if args.command == "inspect":
            result = ledger.inspect(args.application_id, args.request_id)
        elif args.command == "reserve":
            result = ledger.reserve(args.application_id, args.request_id, dry_run=args.dry_run)
        elif args.command == "bind-artifact":
            result = ledger.bind_artifact(args.application_id, args.request_id, args.version_code,
                                          sha256=args.sha256, version=args.version, commit=args.commit, dry_run=args.dry_run)
        else:
            result = ledger.validate_reservation(args.application_id, args.request_id, args.version_code,
                                                 sha256=args.sha256, version=args.version, commit=args.commit)
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0
    except CounterError as error:
        print(json.dumps({"status": "blocked", "reason": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
