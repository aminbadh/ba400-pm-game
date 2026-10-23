# /// script
# requires-python = ">=3.11"
# ///
"""Checks art/LICENSES.md covers every image, sound and licence file under art/.

Lists each file with whether LICENSES.md names it, and exits 1 if any is missing.

Run from the project root: uv run tools/check_licenses.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art"
LISTED_IN = ART / "LICENSES.md"
SKIP_SUFFIXES = {".import", ".md"}
SKIP_NAMES = {".gdignore", ".DS_Store"}


def main() -> None:
    listing = LISTED_IN.read_text()
    missing = []
    for path in sorted(ART.rglob("*")):
        if not path.is_file() or path.suffix in SKIP_SUFFIXES or path.name in SKIP_NAMES:
            continue
        relative = path.relative_to(ROOT).as_posix()
        listed = f"`{relative}`" in listing
        print(f"{'listed ' if listed else 'MISSING'}  {relative}")
        if not listed:
            missing.append(relative)
    if missing:
        print(f"FAIL: {len(missing)} file(s) under art/ are not in {LISTED_IN.relative_to(ROOT)}")
        sys.exit(1)
    print(f"PASS: every file under art/ is in {LISTED_IN.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
