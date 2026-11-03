import importlib.util
import json
from pathlib import Path
import shutil
import sys
import struct
import zipfile
from unittest.mock import patch
import tempfile
import unittest

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import version as tool
import update_tools


class VersionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / "project.godot").write_text('[application]\nconfig/version="0.1.0"\n[pallobby]\nidentity/slug="trial-game"\nidentity/package_name="com.example.trial"\nbuild/version_code=1\n')
        (self.root / "export_presets.cfg").write_text('[preset.0]\nplatform="Android"\n[preset.0.options]\nversion/name="0.1.0"\nversion/code=1\n')

    def tearDown(self):
        self.temporary.cleanup()

    def test_upstream_semver_precedence_and_metadata(self):
        versions = ["1.0.0-alpha.2", "1.0.0-alpha.10", "1.0.0-beta.1", "1.0.0-rc.1", "1.0.0", "1.0.1", "1.1.0", "2.0.0"]
        self.assertEqual(sorted(versions, key=tool.Version.parse), versions)
        self.assertEqual(tool.Version.parse("1.0.0+sha.1"), tool.Version.parse("1.0.0+sha.2"))
        for invalid in ("1.0", "01.0.0", "1.0.0-alpha.01", "", "1.0.0-"):
            with self.assertRaises(ValueError): tool.Version.parse(invalid)

    def test_sync_idempotent_dry_run_and_code_retention(self):
        before = (self.root / "project.godot").read_bytes()
        tool.sync(self.root, 137, "0.2.0-beta.2", True)
        self.assertEqual(before, (self.root / "project.godot").read_bytes())
        tool.sync(self.root, 137, "0.2.0-beta.2")
        self.assertEqual(tool.check(self.root)["version_code"], 137)
        self.assertEqual(tool.sync(self.root)["changed"], [])
        self.assertEqual(tool.sync(self.root, version="0.2.1")["version_code"], 137)
        with self.assertRaises(ValueError): tool.sync(self.root, 2100000001)

    def test_overrides_and_mismatch_rejected(self):
        path = self.root / "override.cfg"
        for text in ('[application]\nconfig/version="9.0.0"', '[application]\nconfig/version.android="9.0.0"', '[application]\nconfig/project_settings_override="hidden.cfg"'):
            path.write_text(text)
            with self.assertRaises(ValueError): tool.check(self.root)
        path.unlink()
        presets = self.root / "export_presets.cfg"
        presets.write_text(presets.read_text().replace('0.1.0', '0.2.0'))
        with self.assertRaises(ValueError): tool.check(self.root)

    def test_promotion_checks_bytes_and_prerelease(self):
        artifact = self.root / "candidate.aab"; artifact.write_bytes(b"immutable tested bytes")
        data = {"product": "trial", "version": "1.0.0", "version_code": 137, "commit": "a" * 40, "environment": "play", "platform": "android", "application_id": "com.studio.trial",
                "bytes": artifact.stat().st_size, "sha256": tool.hashlib.sha256(artifact.read_bytes()).hexdigest()}
        manifest = self.root / "manifest.json"; manifest.write_text(json.dumps(data))
        data["publishable"] = True
        data["artifact_binding"] = {"artifact_bound": True, "artifact": {"sha256": data["sha256"], "version": data["version"], "commit": data["commit"]}}
        manifest.write_text(json.dumps(data))
        self.assertTrue(tool.verify_promotion(artifact, manifest, "production")["verified"])
        with self.assertRaises(ValueError): tool.verify_promotion(artifact, manifest, "production", True)
        data["version"] = "1.0.0-rc.1"; manifest.write_text(json.dumps(data))
        data["artifact_binding"]["artifact"]["version"] = data["version"]
        manifest.write_text(json.dumps(data))
        self.assertTrue(tool.verify_promotion(artifact, manifest, "production")["verified"])
        artifact.write_bytes(b"rebuilt bytes")
        with self.assertRaises(ValueError): tool.verify_promotion(artifact, manifest, "internal")

    def test_pinned_updater_rejects_tampering_before_writes(self):
        payload = b"print('ok')\n"
        raw = json.dumps({"files": {"version.py": update_tools.digest(payload)}}).encode()
        result = update_tools.update(self.root, "a" * 40, update_tools.digest(raw), True, lambda name: raw if name == "TOOLSET.json" else payload)
        self.assertTrue(result["dry_run"])
        self.assertFalse((self.root / "scripts/versioning/version.py").exists())
        with self.assertRaises(ValueError):
            update_tools.update(self.root, "a" * 40, update_tools.digest(raw), False, lambda name: raw if name == "TOOLSET.json" else b"tampered")
        self.assertFalse((self.root / "scripts/versioning/version.py").exists())

    def test_desktop_source_has_no_android_configuration(self):
        (self.root / "export_presets.cfg").unlink()
        (self.root / "project.godot").write_text('[application]\nconfig/name="Desktop Trial"\nconfig/version="0.1.0-alpha.1+local"\n')
        self.assertEqual(tool.check(self.root)["version"], "0.1.0-alpha.1+local")
        self.assertIsNone(tool.check(self.root)["version_code"])
        self.assertEqual(tool.sync(self.root, version="0.1.0-beta.1")["version"], "0.1.0-beta.1")
        self.assertFalse((self.root / "export_presets.cfg").exists())
        with self.assertRaises(ValueError): tool.sync(self.root, code=1)

    def test_actual_runtime_ecfg_matches_android_manifest_and_source(self):
        artifact = self.root / "trial.apk"
        def pack(runtime_version):
            entries = {"application/config/version": struct.pack("<II", 4, len(runtime_version)) + runtime_version.encode() + b"\0" * ((-len(runtime_version)) % 4),
                       "pallobby/build/version_code": struct.pack("<Ii", 2, 1)}
            data = b"ECFG" + struct.pack("<I", len(entries))
            for key, value in entries.items(): data += struct.pack("<I", len(key)) + key.encode() + struct.pack("<I", len(value)) + value
            with zipfile.ZipFile(artifact, "w") as archive: archive.writestr("assets/project.binary", data)
        pack("0.1.0")
        with patch.object(tool, "run", return_value="package: name='com.example.trial.qa' versionCode='1' versionName='0.1.0'"):
            actual = tool.inspect_artifact(artifact, aapt2="fixture-aapt2")
            self.assertEqual(actual["runtime_version"], "0.1.0")
            with self.assertRaises(ValueError): tool.manifest(self.root, artifact, "android", "internal", aapt2="fixture-aapt2", environment="play")
            tool.sync(self.root, version="0.1.1")
            with self.assertRaises(ValueError): tool.manifest(self.root, artifact, "android", "local", aapt2="fixture-aapt2", environment="qa")
            pack("9.0.0")
            with self.assertRaises(ValueError): tool.inspect_artifact(artifact, aapt2="fixture-aapt2")


if __name__ == "__main__": unittest.main()
