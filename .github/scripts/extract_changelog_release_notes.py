#!/usr/bin/env python3
"""Extract one Keep a Changelog section for a GitHub Release."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def extract_section(changelog: str, tag: str) -> str:
    escaped_tag = re.escape(tag)
    heading = re.compile(
        rf"^##\s+\[?{escaped_tag}\]?(?:\([^)]*\))?(?:\s+.*)?$",
        re.IGNORECASE,
    )
    next_heading = re.compile(r"^##\s+")
    lines = changelog.splitlines(keepends=True)
    start = next((index for index, line in enumerate(lines) if heading.match(line.strip())), None)
    if start is None:
        raise ValueError(f"No Keep a Changelog section found for version {tag}.")

    section: list[str] = []
    for line in lines[start + 1 :]:
        if next_heading.match(line):
            break
        section.append(line)

    reference_definition = re.compile(r"^\s*\[[^\]]+\]:\s+\S+")
    first_reference = next(
        (
            index
            for index, line in enumerate(section)
            if reference_definition.match(line)
            and all(
                not candidate.strip() or reference_definition.match(candidate)
                for candidate in section[index:]
            )
        ),
        None,
    )
    if first_reference is not None:
        section = section[:first_reference]

    notes = "".join(section).strip()
    if not notes:
        raise ValueError(f"The changelog section for version {tag} is empty.")
    return notes + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--changelog", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    try:
        notes = extract_section(args.changelog.read_text(encoding="utf-8"), args.tag)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    args.output.write_text(notes, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
