#!/usr/bin/env python3
"""Select the Entime Windows release profile from its SemVer tag."""

from __future__ import annotations

import argparse
import json
import re


SEMVER_PATTERN = re.compile(
    r"^(0|[1-9][0-9]*)\."
    r"(0|[1-9][0-9]*)\."
    r"(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
)
CURRENT_LAYOUT_SINCE = (0, 9, 0)


def parse_version(tag: str) -> tuple[int, int, int]:
    match = SEMVER_PATTERN.fullmatch(tag)
    if match is None:
        raise ValueError(f"Invalid release tag: {tag!r}.")
    prerelease = match.group(4)
    if prerelease is not None:
        for identifier in prerelease.split("."):
            if (
                identifier.isdigit()
                and len(identifier) > 1
                and identifier[0] == "0"
            ):
                raise ValueError(f"Invalid release tag: {tag!r}.")
    # Layout selection follows the numeric application version. The suffix
    # only controls release precedence and publication as a prerelease.
    return tuple(int(part) for part in match.groups()[:3])


def select_release_profile(tag: str) -> dict[str, object]:
    if parse_version(tag) < CURRENT_LAYOUT_SINCE:
        return {
            "profile": "legacy",
            "project_file": "Entime.lpi",
            "build_mode": "Release",
            "executable_path": "release/Entime.exe",
        }
    return {
        "profile": "current",
        "project_file": "entime.lpi",
        "build_mode": "release",
        "executable_path": "build/bin/release/Entime.exe",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()

    try:
        profile = select_release_profile(args.tag)
    except ValueError as error:
        parser.error(str(error))

    print(json.dumps(profile, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
