#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_MODE="${1:-qt6}"
PROJECT_FILE="$ROOT_DIR/entime.lpi"
PACKAGE_FILE="$ROOT_DIR/packages/myforks/myforks.lpk"
LANGUAGE_DIR="$ROOT_DIR/languages"
OUTPUT_DIR="$ROOT_DIR/build/bin/$BUILD_MODE"

if ! command -v lazbuild >/dev/null 2>&1; then
  echo "Error: lazbuild is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" || ! -f "$PACKAGE_FILE" ]]; then
  echo "Error: project or local package file is missing."
  exit 1
fi

echo "==> Building Entime ($BUILD_MODE)"
lazbuild --add-package-link "$PACKAGE_FILE"
lazbuild --no-write-project --ws=qt6 --build-mode="$BUILD_MODE" "$PROJECT_FILE"

echo "==> Copying runtime resources"
mkdir -p "$OUTPUT_DIR/languages"
cp -a "$LANGUAGE_DIR/." "$OUTPUT_DIR/languages/"

echo "Build completed: $OUTPUT_DIR"
