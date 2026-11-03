#!/usr/bin/env python3
"""Explicit, pinned installation for AAB metadata inspection (not needed at game runtime)."""
import argparse
import hashlib
from pathlib import Path
import urllib.request

VERSION = "1.18.3"
SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
URL = f"https://github.com/google/bundletool/releases/download/{VERSION}/bundletool-all-{VERSION}.jar"


def install(destination):
    if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == SHA256:
        return
    with urllib.request.urlopen(URL, timeout=60) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError("bundletool checksum differs from the pinned official release")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    install(args.output)
    print(str(args.output.resolve()))
