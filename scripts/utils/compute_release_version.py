#!/usr/bin/env python3
"""Compute release version/tag for automatic GitHub releases.

Version format: X.Y.Z.W-<short_sha>
Tag format: vX.Y.Z.W-<short_sha>
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from typing import Iterable, Optional, Tuple

VersionTuple = Tuple[int, int, int, int]

VERSION_TAG_PATTERN = re.compile(r"^v(\d+)\.(\d+)\.(\d+)\.(\d+)-([0-9a-fA-F]{7,40})$")
VERSION_OVERRIDE_PATTERN = re.compile(r"\[version:(prod|pre|dev|change)\]", re.IGNORECASE)
SCOPE_ORDER = ("prod", "pre", "dev", "change")
SCOPE_BY_BRANCH = {
    "main": "prod",
    "pre": "pre",
    "dev": "dev",
}


def _run_git(args: Iterable[str], allow_fail: bool = False) -> str:
    process = subprocess.run(
        ["git", *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if process.returncode != 0 and not allow_fail:
        raise RuntimeError(process.stderr.strip() or process.stdout.strip() or "git command failed")
    return process.stdout.strip()


def _parse_version_from_tag(tag: str) -> Optional[VersionTuple]:
    match = VERSION_TAG_PATTERN.match(tag.strip())
    if match is None:
        return None
    return tuple(int(match.group(idx)) for idx in range(1, 5))


def _collect_matching_tags() -> Tuple[VersionTuple, ...]:
    raw = _run_git(["tag", "--list"], allow_fail=True)
    if not raw:
        return ()
    versions = []
    for tag in raw.splitlines():
        version = _parse_version_from_tag(tag)
        if version is not None:
            versions.append(version)
    versions.sort()
    return tuple(versions)


def _format_version(version: VersionTuple) -> str:
    return ".".join(str(part) for part in version)


def _bump(version: VersionTuple, scope: str) -> VersionTuple:
    parts = list(version)
    scope_idx = SCOPE_ORDER.index(scope)
    parts[scope_idx] += 1
    for idx in range(scope_idx + 1, len(parts)):
        parts[idx] = 0
    return tuple(parts)  # type: ignore[return-value]


def _resolve_scope(manual_scope: Optional[str], branch: str, commit_message: str) -> str:
    if manual_scope:
        return manual_scope
    override_match = VERSION_OVERRIDE_PATTERN.search(commit_message)
    if override_match is not None:
        return override_match.group(1).lower()
    if branch in SCOPE_BY_BRANCH:
        return SCOPE_BY_BRANCH[branch]
    return "change"


def _write_output(name: str, value: str) -> None:
    output_path = os.getenv("GITHUB_OUTPUT")
    if not output_path:
        return
    with open(output_path, "a", encoding="utf-8") as handle:
        handle.write(f"{name}={value}\n")


def _as_bool_text(value: str) -> str:
    return "true" if value.lower() in {"1", "true", "yes", "on"} else "false"


def main() -> int:
    parser = argparse.ArgumentParser(description="Compute release version and tag.")
    parser.add_argument("--branch", default=os.getenv("GITHUB_REF_NAME", ""))
    parser.add_argument("--scope", choices=SCOPE_ORDER)
    parser.add_argument("--commit-message", default="")
    parser.add_argument("--pre-release", default="true")
    args = parser.parse_args()

    branch = args.branch.strip()
    if not branch:
        branch = _run_git(["rev-parse", "--abbrev-ref", "HEAD"])

    commit_message = args.commit_message.strip()
    if not commit_message:
        commit_message = _run_git(["log", "-1", "--pretty=%B"])

    short_sha = _run_git(["rev-parse", "--short=7", "HEAD"])
    pre_release = _as_bool_text(args.pre_release)
    bump_scope = _resolve_scope(args.scope, branch, commit_message)

    versions = _collect_matching_tags()
    base_version: VersionTuple = versions[-1] if versions else (0, 0, 0, 0)
    next_version = base_version if not versions else _bump(base_version, bump_scope)
    tag = f"v{_format_version(next_version)}-{short_sha}"

    version_text = _format_version(next_version)
    base_version_text = _format_version(base_version)
    release_name = f"{version_text}-{short_sha} ({branch})"

    outputs = {
        "version": version_text,
        "base_version": base_version_text,
        "tag": tag,
        "bump_scope": bump_scope,
        "pre_release": pre_release,
        "release_name": release_name,
        "branch": branch,
        "short_sha": short_sha,
    }

    for key, value in outputs.items():
        _write_output(key, value)

    for key, value in outputs.items():
        print(f"{key}={value}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"error={exc}", file=sys.stderr)
        raise SystemExit(1)
