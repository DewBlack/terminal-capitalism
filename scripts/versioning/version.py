#!/usr/bin/env python3
"""Offline product version tooling. project.godot is the only editable version source."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

sys.path.insert(0, str(Path(__file__).parent / "vendor"))
from semver import Version

MAX_CODE = 2100000000
ANDROID = "{http://schemas.android.com/apk/res/android}"


def run(*args, cwd=None):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if result.returncode:
        raise ValueError(f"Command failed ({args[0]}): {result.stderr.strip()}")
    return result.stdout.strip()


def read(path):
    return path.read_text(encoding="utf-8-sig")


def field(text, section, key):
    blocks = re.split(r"(?m)^\[([^\]\r\n]+)\]\s*$", text)
    values = []
    for i in range(1, len(blocks), 2):
        if blocks[i] == section:
            values.extend(re.findall(r"(?m)^" + re.escape(key) + r"\s*=\s*(.*?)\s*$", blocks[i + 1]))
    if len(values) != 1:
        raise ValueError(f"Expected one [{section}] {key}; found {len(values)}")
    return values[0].strip('"')


def replace_field(text, section, key, value):
    pattern = r"(?ms)(^\[" + re.escape(section) + r"\]\s*\n)(.*?)(?=^\[|\Z)"
    count = 0
    def block(match):
        nonlocal count
        body, count = re.subn(r"(?m)^" + re.escape(key) + r"\s*=.*$", key + "=" + value, match[2])
        return match[1] + body
    result = re.sub(pattern, block, text)
    if count != 1:
        raise ValueError(f"Expected one [{section}] {key}; refusing to edit")
    return result


def optional_field(text, section, key, default=None):
    try: return field(text, section, key)
    except ValueError: return default


def source(root):
    project = read(root / "project.godot")
    version = field(project, "application", "config/version")
    Version.parse(version)
    # An override may silently change the version used by exported/runtime Godot.
    for path in (root / "project.godot", root / "override.cfg"):
        if not path.exists():
            continue
        content = read(path)
        if re.search(r"(?m)^\s*config/(?:version\.|project_settings_override)", content):
            raise ValueError(f"{path.name}: remove feature/version or project_settings_override overrides")
        if path.name == "override.cfg" and re.search(r"(?m)^\s*(?:config/version|build/version_code)\s*=", content):
            raise ValueError("override.cfg must not override product version or build code")
    code_text = optional_field(project, "pallobby", "build/version_code")
    code = int(code_text) if code_text is not None else None
    if code is not None and not 0 <= code <= MAX_CODE:
        raise ValueError("Runtime build code outside Android range 0..2100000000")
    return {"product": optional_field(project, "pallobby", "identity/slug", re.sub(r"[^a-z0-9]+", "-", optional_field(project, "application", "config/name", root.name).lower()).strip("-")), "version": version,
            "application_id": optional_field(project, "pallobby", "identity/package_name"), "version_code": code}


def android_presets(root):
    if not (root / "export_presets.cfg").exists(): return "", []
    text = read(root / "export_presets.cfg")
    result = []
    for section in re.findall(r"(?m)^\[(preset\.\d+)\]\s*$", text):
        if field(text, section, "platform") == "Android":
            result.append(section + ".options")
    return text, result


def check(root, release=False):
    info = source(root)
    text, presets = android_presets(root)
    if presets and Version.parse(info["version"]).build:
        raise ValueError("Android adapter does not project +build metadata; keep provenance in artifact manifest instead")
    for section in presets:
        if field(text, section, "version/name") != info["version"]:
            raise ValueError(f"{section} version/name differs from project.godot; run sync")
        if int(field(text, section, "version/code")) != info["version_code"]:
            raise ValueError(f"{section} version/code differs from runtime build code; run sync")
    if presets and (info["version_code"] is None or info["version_code"] < 1 or not info["application_id"]):
        raise ValueError("Android requires pallobby identity/package_name and positive build/version_code; mirror local preset code before sync")
    if release and presets:
        if info["version_code"] < 1 or re.search(r"(?:template|example|placeholder|demo)", info["application_id"], re.I):
            raise ValueError("Release requires a real application ID and confirmed build code; see studio VERSIONING.md")
        request_id = os.environ.get("PLG_ANDROID_RESERVATION_ID")
        if not request_id:
            raise ValueError("Release requires PLG_ANDROID_RESERVATION_ID from android_counter.py reserve")
        from android_counter import Ledger, CounterError
        try:
            Ledger().validate_reservation(info["application_id"], request_id, info["version_code"])
        except CounterError as error:
            raise ValueError(str(error)) from error
    return info


def sync(root, code=None, version=None, dry_run=False):
    info = source(root)
    if code is not None and not 1 <= code <= MAX_CODE:
        raise ValueError("Build code must be 1..2100000000; publication reservations come from android_counter.py")
    if version is not None:
        Version.parse(version)
        if android_presets(root)[1] and Version.parse(version).build:
            raise ValueError("Android adapter does not project +build; record provenance in artifact manifest")
    project_path, presets_path = root / "project.godot", root / "export_presets.cfg"
    if code is not None and not android_presets(root)[1]: raise ValueError("No Android adapter configured; --code is only for Android")
    project = read(project_path)
    if version is not None:
        project = replace_field(project, "application", "config/version", json.dumps(version))
        info["version"] = version
    if code is not None:
        project = replace_field(project, "pallobby", "build/version_code", str(code))
        info["version_code"] = code
    presets, sections = android_presets(root)
    for section in sections:
        presets = replace_field(presets, section, "version/name", json.dumps(info["version"]))
        presets = replace_field(presets, section, "version/code", str(info["version_code"]))
    changed = []
    outputs = [(project_path, project)] + ([(presets_path, presets)] if presets_path.exists() else [])
    for path, text in outputs:
        if read(path) != text:
            changed.append(path.name)
            if not dry_run:
                path.write_text(text, encoding="utf-8", newline="\n")
    return {**info, "changed": changed, "dry_run": dry_run}


def commits(root, since=None):
    return run("git", "log", "--format=%s", f"{since}..HEAD" if since else "HEAD", cwd=root).splitlines()


def proposal(root, bump, phase, since):
    current = Version.parse(source(root)["version"])
    messages = commits(root, since)
    if bump is None:
        relevant = [m for m in messages if re.match(r"(?:feat|fix|perf|revert)(?:\([^)]*\))?!?:", m)]
        if not relevant:
            return str(current)
        # Breaking changes require a human product decision, so only propose it.
        bump = "major" if any(re.match(r"\w+(?:\([^)]*\))?!:", m) for m in relevant) else "minor" if any(m.startswith("feat") for m in relevant) else "patch"
    base = getattr(current, "bump_" + bump)()
    return str(base if phase == "stable" else base.replace(prerelease=f"{phase}.1"))


def inspect_artifact(path, aapt2=None, bundletool=None):
    path = path.resolve(strict=True)
    if path.suffix.lower() == ".pck":
        from godot_runtime import metadata
        runtime = metadata(path)
        Version.parse(runtime["runtime_version"])
        return {**runtime, "application_id": None, "version": runtime["runtime_version"], "version_code": None,
                "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
    if path.suffix.lower() == ".apk":
        executable = aapt2 or shutil.which("aapt2")
        if not executable:
            roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
            if os.environ.get("LOCALAPPDATA"): roots.append(str(Path(os.environ["LOCALAPPDATA"]) / "Android/Sdk"))
            candidates = [item for sdk in roots if sdk for item in (Path(sdk) / "build-tools").glob("*/aapt2*") if item.is_file()]
            if candidates: executable = str(sorted(candidates, key=lambda item: item.parent.name)[-1])
        if not executable:
            raise ValueError("APK inspection requires --aapt2 PATH (Android SDK build-tools)")
        output = run(str(executable), "dump", "badging", str(path))
        match = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", output)
        if not match:
            raise ValueError("aapt2 returned no APK version metadata")
        package, code, version = match.groups()
    elif path.suffix.lower() == ".aab":
        jar = bundletool or __import__("os").environ.get("BUNDLETOOL_JAR")
        if not jar:
            raise ValueError("AAB inspection requires --bundletool PATH or BUNDLETOOL_JAR")
        xml = run("java", "-jar", str(jar), "dump", "manifest", f"--bundle={path}", "--module=base")
        manifest = ET.fromstring(xml)
        package, code, version = manifest.get("package"), manifest.get(ANDROID + "versionCode"), manifest.get(ANDROID + "versionName")
    else:
        raise ValueError("Artifact must be APK, AAB or standalone unencrypted Godot PCK")
    Version.parse(version)
    if not 1 <= int(code) <= MAX_CODE:
        raise ValueError("Artifact versionCode outside Play range")
    from godot_runtime import metadata
    runtime = metadata(path)
    if runtime["runtime_version"] != version or runtime["runtime_version_code"] != int(code):
        raise ValueError("Android manifest and installed Godot runtime version metadata differ")
    return {**runtime, "application_id": package, "version": version, "version_code": int(code),
            "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}


def manifest(root, artifact, platform, channel, aapt2=None, bundletool=None, environment="play"):
    info = check(root)
    is_android = artifact.suffix.lower() in (".apk", ".aab")
    if is_android != (platform == "android"):
        raise ValueError("Artifact format and declared platform differ: APK/AAB require android, PCK requires desktop/web platform")
    actual = inspect_artifact(artifact, aapt2, bundletool)
    for key in (("version", "version_code") if actual["version_code"] is not None else ("version",)):
        if actual[key] != info[key]:
            raise ValueError(f"Artifact {key} does not match source/runtime: {actual[key]} != {info[key]}")
    suffix = {"play": "", "dev": ".dev", "qa": ".qa", "desktop": "", "web": ""}[environment]
    if actual["application_id"] is not None and actual["application_id"] != info["application_id"] + suffix:
        raise ValueError(f"Artifact application ID does not match the {environment} environment of this product")
    try:
        commit = run("git", "rev-parse", "HEAD", cwd=root)
        dirty = bool(run("git", "status", "--porcelain", "--untracked-files=no", cwd=root))
    except ValueError:
        if environment == "play": raise
        commit, dirty = None, True
    return {**actual, "schema": 1, "product": info["product"], "commit": commit, "source_dirty": dirty,
            "reservation_id": os.environ.get("PLG_ANDROID_RESERVATION_ID"),
            "platform": platform, "channel": channel, "environment": environment, "publishable": False}


def verify_promotion(artifact, evidence, target, rebuild=False):
    data = json.loads(read(evidence))
    if rebuild:
        raise ValueError("A rebuild is a new artifact and requires a new reservation and acceptance gates")
    if hashlib.sha256(artifact.read_bytes()).hexdigest() != data["sha256"] or artifact.stat().st_size != data["bytes"]:
        raise ValueError("Promotion artifact differs from the accepted checksum/size")
    if not data.get("commit") or not data.get("product"):
        raise ValueError("Incomplete artifact evidence; regenerate manifest from inspected artifact")
    if artifact.suffix.lower() == ".pck" and data.get("platform") != "android":
        Version.parse(data["version"])
        return {**data, "target": target, "verified": True}
    if not isinstance(data.get("version_code"), int) or data["version_code"] < 1:
        raise ValueError("Missing Android build code")
    if data.get("environment") != "play" or data.get("application_id", "").endswith((".dev", ".qa")):
        raise ValueError("Local DEV/QA artifacts cannot be promoted to a Google Play track")
    binding = data.get("artifact_binding", {})
    if not data.get("publishable") or not binding.get("artifact_bound"):
        raise ValueError("Promotion requires artifact metadata bound to the authoritative reservation")
    if binding.get("artifact") != {"sha256": data["sha256"], "version": data["version"], "commit": data["commit"]}:
        raise ValueError("Reservation binding differs from the accepted artifact")
    Version.parse(data["version"])
    return {**data, "target": target, "verified": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("show"); p.add_argument("--json", action="store_true")
    p = sub.add_parser("check"); p.add_argument("--release", action="store_true")
    for command in ("sync", "prepare"):
        p = sub.add_parser(command)
        if command == "prepare":
            p.add_argument("version"); p.add_argument("--allow-major", action="store_true")
        p.add_argument("--code", type=int); p.add_argument("--dry-run", action="store_true")
    p = sub.add_parser("propose"); p.add_argument("bump", nargs="?", choices=["patch", "minor", "major"]); p.add_argument("--phase", choices=["alpha", "beta", "rc", "stable"], default="stable"); p.add_argument("--since")
    p = sub.add_parser("changelog"); p.add_argument("--since"); p.add_argument("--output", type=Path); p.add_argument("--dry-run", action="store_true")
    for command in ("artifact-inspect", "manifest"):
        p = sub.add_parser(command); p.add_argument("artifact", type=Path); p.add_argument("--aapt2"); p.add_argument("--bundletool")
        if command == "manifest":
            p.add_argument("--platform", default="android"); p.add_argument("--channel", default="internal"); p.add_argument("--environment", choices=["play", "dev", "qa", "desktop", "web"], default="play"); p.add_argument("--output", type=Path); p.add_argument("--dry-run", action="store_true"); p.add_argument("--bind-reservation", action="store_true")
    p = sub.add_parser("promotion-verify"); p.add_argument("artifact", type=Path); p.add_argument("manifest", type=Path); p.add_argument("--target", default="production"); p.add_argument("--rebuild", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "show": result = source(args.root)
        elif args.command == "check": result = check(args.root, args.release)
        elif args.command == "sync": result = sync(args.root, args.code, dry_run=args.dry_run)
        elif args.command == "prepare":
            old, new = Version.parse(source(args.root)["version"]), Version.parse(args.version)
            if new.prerelease and not re.fullmatch(r"(?:alpha|beta|rc)\.[1-9]\d*", new.prerelease):
                raise ValueError("New prereleases use alpha.N, beta.N or rc.N; existing legacy source is retained until an explicit next target")
            if new < old: raise ValueError("Version cannot move backwards; published history remains immutable")
            if new.major > old.major and not args.allow_major: raise ValueError("MAJOR requires explicit product decision: use --allow-major after recording justification")
            result = sync(args.root, args.code, args.version, args.dry_run)
        elif args.command == "propose": result = {"proposed": proposal(args.root, args.bump, args.phase, args.since), "applied": False}
        elif args.command == "changelog":
            result = "## Unreleased\n\n" + "\n".join("- " + message for message in commits(args.root, args.since)) + "\n"
            if args.output and not args.dry_run: args.output.write_text(result, encoding="utf-8")
        elif args.command == "artifact-inspect": result = inspect_artifact(args.artifact, args.aapt2, args.bundletool)
        elif args.command == "manifest":
            result = manifest(args.root, args.artifact, args.platform, args.channel, args.aapt2, args.bundletool, args.environment)
            if args.bind_reservation:
                if args.environment != "play": raise ValueError("Local DEV/QA artifacts never bind publication reservations")
                if not result["reservation_id"]: raise ValueError("Set PLG_ANDROID_RESERVATION_ID before binding an inspected artifact")
                from android_counter import Ledger, CounterError
                try:
                    result["artifact_binding"] = Ledger().bind_artifact(result["application_id"], result["reservation_id"], result["version_code"],
                        sha256=result["sha256"], version=result["version"], commit=result["commit"], dry_run=args.dry_run)
                    result["publishable"] = not args.dry_run and result["artifact_binding"].get("artifact_bound", False)
                except CounterError as error: raise ValueError(str(error)) from error
            if args.output and not args.dry_run: args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        else:
            result = verify_promotion(args.artifact, args.manifest, args.target, args.rebuild)
            if result.get("platform") == "android":
                from android_counter import Ledger, CounterError
                try:
                    Ledger().validate_reservation(result["application_id"], result["reservation_id"], result["version_code"],
                        sha256=result["sha256"], version=result["version"], commit=result["commit"])
                except CounterError as error: raise ValueError(str(error)) from error
        print(result if isinstance(result, str) else json.dumps(result, indent=2))
        return 0
    except (ValueError, OSError, KeyError, ET.ParseError, zipfile.BadZipFile) as error:
        print(f"VERSION_ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
