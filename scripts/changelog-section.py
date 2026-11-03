"""Print one version's section of CombatMode/CHANGELOG.md (release notes, Discord embed).

    python scripts/changelog-section.py VERSION [--max-chars N]

VERSION may carry a leading "v". The section runs from its "## [x.y.z]" heading to the next one.
--max-chars cuts at a line boundary and appends "[... truncated]" (Discord embeds take 4096).
Exits 1 when the section is missing.
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG = os.path.join(ROOT, "CombatMode", "CHANGELOG.md")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("version")
    parser.add_argument("--max-chars", type=int, default=0)
    args = parser.parse_args()

    version = args.version.lstrip("v")
    with open(CHANGELOG, encoding="utf-8") as f:
        text = f.read().replace("\r\n", "\n")
    match = re.search(r"^##\s+\[v?" + re.escape(version) + r"\].*?(?=^##\s+\[|^\[[^\]]+\]:\s|\Z)", text, re.MULTILINE | re.DOTALL)
    if not match:
        print(f"No changelog section found for version {version}", file=sys.stderr)
        sys.exit(1)

    section = match.group(0).strip()
    if args.max_chars and len(section) > args.max_chars:
        section = section[: args.max_chars].rsplit("\n", 1)[0] + "\n\n[... truncated]"
    sys.stdout.reconfigure(encoding="utf-8")
    print(section)


main()
