#!/usr/bin/env python3
"""Resolve Lazarus packages for an Entime release version."""

from __future__ import annotations

import argparse
import json
import re
from copy import deepcopy
from pathlib import Path


SEMVER = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
SEMVER_PATTERN = re.compile(rf"^{SEMVER}$")
COMPARATOR_PATTERN = re.compile(rf"^(<=|>=|<|>|=)?{SEMVER}$")


def parse_version(value: str) -> tuple[int, int, int]:
    match = SEMVER_PATTERN.fullmatch(value)
    if match is None:
        raise ValueError(f"Invalid stable SemVer: {value!r}.")
    return tuple(int(part) for part in match.groups())


def comparator_matches(version: tuple[int, int, int], expression: str) -> bool:
    match = COMPARATOR_PATTERN.fullmatch(expression)
    if match is None:
        raise ValueError(f"Invalid version comparator: {expression!r}.")
    operator = match.group(1) or "="
    expected = tuple(int(part) for part in match.groups()[1:])
    return {
        "=": version == expected,
        ">": version > expected,
        ">=": version >= expected,
        "<": version < expected,
        "<=": version <= expected,
    }[operator]


def version_matches(version: tuple[int, int, int], expression: str) -> bool:
    expression = expression.strip()
    if expression == "*":
        return True
    if not expression:
        raise ValueError("Version range must not be empty.")

    clause_results: list[list[bool]] = []
    for clause in expression.split("||"):
        comparators = clause.replace(",", " ").split()
        if not comparators:
            raise ValueError(f"Invalid version range: {expression!r}.")
        clause_results.append(
            [comparator_matches(version, item) for item in comparators]
        )
    return any(all(results) for results in clause_results)


def select_package_configuration(
    configuration: dict[str, object], tag: str
) -> dict[str, object]:
    if configuration.get("schema") != 2:
        raise ValueError("Versioned Lazarus package configuration must use schema 2.")
    repository = configuration.get("repository")
    packages = configuration.get("packages")
    if not isinstance(repository, str) or not repository:
        raise ValueError("Package repository is missing.")
    if not isinstance(packages, list):
        raise ValueError("Package list is missing.")

    version = parse_version(tag)
    selected: list[dict[str, object]] = []
    selected_names: set[str] = set()
    for source_package in packages:
        if not isinstance(source_package, dict):
            raise ValueError("Every package entry must be an object.")
        package = deepcopy(source_package)
        name = package.get("name")
        version_range = package.pop("entime_version_range", None)
        if not isinstance(name, str) or not name:
            raise ValueError("Every package must have a name.")
        if not isinstance(version_range, str):
            raise ValueError(f"Package {name} has no Entime version range.")
        if not version_matches(version, version_range):
            continue
        if name.casefold() in selected_names:
            raise ValueError(f"Several package definitions match {tag}: {name}.")
        selected_names.add(name.casefold())
        selected.append(package)

    return {"schema": 1, "repository": repository, "packages": selected}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    try:
        configuration = json.loads(args.config.read_text(encoding="utf-8"))
        selected = select_package_configuration(configuration, args.tag)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(selected, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except (OSError, json.JSONDecodeError, ValueError) as error:
        parser.error(str(error))

    names = ", ".join(package["name"] for package in selected["packages"])
    print(f"Selected Lazarus packages for {args.tag}: {names}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
