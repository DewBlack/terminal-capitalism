#!/usr/bin/env python3
"""Compatibility entry point: inspect the source; never increment by branch/commit."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "versioning"))
from version import main
if len(sys.argv) == 1:
    sys.argv.append("show")
if __name__ == "__main__":
    raise SystemExit(main())
