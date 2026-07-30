#!/usr/bin/env python3
"""Select and validate a release tag for the manual release workflow."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SEMVER_PATTERN = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
EXISTING_MODES = {"publish_existing", "rebuild_existing"}


def version_key(tag: str) -> tuple[int, int, int]:
    match = SEMVER_PATTERN.fullmatch(tag)
    if not match:
        raise ValueError(f"Unsupported release tag '{tag}'.")
    return tuple(int(part) for part in match.groups())


def supported_tags(tags: list[str]) -> list[str]:
    unique = {tag.strip() for tag in tags if SEMVER_PATTERN.fullmatch(tag.strip())}
    return sorted(unique, key=version_key)


def select_release_tag(
    mode: str,
    requested_tag: str,
    source_tags: list[str],
    local_tags: list[str],
) -> str | None:
    requested_tag = requested_tag.strip()
    local = supported_tags(local_tags)

    if mode == "sync_next":
        source = supported_tags(source_tags)
        current_key = version_key(local[-1]) if local else (0, 0, 0)
        if requested_tag:
            requested_key = version_key(requested_tag)
            if requested_tag not in source:
                raise ValueError(
                    f"Codeberg does not contain supported release tag '{requested_tag}'."
                )
            if requested_key <= current_key:
                raise ValueError(
                    f"Target tag {requested_tag} is not newer than "
                    f"the current local release {'.'.join(map(str, current_key))}."
                )
            return requested_tag
        return next((tag for tag in source if version_key(tag) > current_key), None)

    if mode in EXISTING_MODES:
        if not requested_tag:
            raise ValueError(f"{mode} requires target_tag.")
        version_key(requested_tag)
        if requested_tag not in local:
            raise ValueError(f"Local tag {requested_tag} does not exist.")
        return requested_tag

    raise ValueError(f"Unsupported mode '{mode}'.")


def read_tags(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8-sig").splitlines()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        required=True,
        choices=("sync_next", "publish_existing", "rebuild_existing"),
    )
    parser.add_argument("--requested-tag", default="")
    parser.add_argument("--source-tags", type=Path, required=True)
    parser.add_argument("--local-tags", type=Path, required=True)
    args = parser.parse_args()

    try:
        selected = select_release_tag(
            args.mode,
            args.requested_tag,
            read_tags(args.source_tags),
            read_tags(args.local_tags),
        )
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    if selected:
        print(selected)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
