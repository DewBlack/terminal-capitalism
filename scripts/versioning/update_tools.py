#!/usr/bin/env python3
"""Update pinned shared tools from an immutable template revision; never from a branch."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import urllib.request
import subprocess

UPSTREAM = "https://api.github.com/repos/pallobbygames/pallobbygames-template/contents"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def update(root, revision=None, manifest_sha256=None, dry_run=False, fetch=None):
    lockpath = root / "scripts/versioning.lock.json"
    previous = json.loads(lockpath.read_text()) if lockpath.exists() else {}
    if revision and not manifest_sha256:
        raise ValueError("An update requires both --revision and --manifest-sha256 from the reviewed upstream PR")
    revision = revision or previous.get("revision", "")
    manifest_sha256 = manifest_sha256 or previous.get("manifest_sha256", "")
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or not re.fullmatch(r"[0-9a-f]{64}", manifest_sha256):
        raise ValueError("Missing immutable upstream revision/manifest SHA-256; pin a reviewed tool release")
    if fetch is None:
        token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
        if not token:
            try:
                credential = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True)
                if credential.returncode == 0: token = credential.stdout.strip()
            except OSError: pass
        def fetch(path):
            headers = {"Accept": "application/vnd.github.raw+json", "User-Agent": "PalLobbyGames-versioning"}
            if token: headers["Authorization"] = "Bearer " + token
            request = urllib.request.Request(f"{UPSTREAM}/scripts/versioning/{path}?ref={revision}", headers=headers)
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
    raw = fetch("TOOLSET.json")
    if digest(raw) != manifest_sha256:
        raise ValueError("Upstream TOOLSET.json checksum differs from reviewed pin")
    manifest = json.loads(raw)
    pending = {"TOOLSET.json": raw}
    for name, expected in manifest["files"].items():
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "\\" in name or name == "TOOLSET.json":
            raise ValueError("Unsafe upstream tool path")
        data = fetch(name)
        if digest(data) != expected:
            raise ValueError(f"Upstream checksum mismatch: {name}")
        pending[name] = data
    # Fetch/verify the entire set before replacing any file.
    if not dry_run:
        for name, data in pending.items():
            destination = root / "scripts/versioning" / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        lockpath.write_text(json.dumps({"upstream": "https://github.com/pallobbygames/pallobbygames-template",
                                       "revision": revision, "manifest_sha256": manifest_sha256}, indent=2) + "\n")
    return {"revision": revision, "files_verified": len(pending), "dry_run": dry_run}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--revision"); parser.add_argument("--manifest-sha256"); parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        print(json.dumps(update(args.root, args.revision, args.manifest_sha256, args.dry_run), indent=2))
    except (ValueError, OSError) as error:
        parser.exit(1, f"TOOL_UPDATE_ERROR: {error}\n")
