#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"
PROJECT_FILE="$TESTS_DIR/entimetests.lpi"
BUILD_DIR="$TESTS_DIR/.test_build"
TEST_BINARY="$BUILD_DIR/entimetests"
TEST_RESOURCE="$TESTS_DIR/entimetests.res"
BUILD_LOG="$BUILD_DIR/lazbuild.log"

if ! command -v lazbuild >/dev/null 2>&1; then
  echo "Error: lazbuild is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Error: unit test project not found: $PROJECT_FILE"
  exit 1
fi

cleanup() {
  rm -rf "$BUILD_DIR"
  rm -f "$TEST_RESOURCE"
}

trap cleanup EXIT
rm -rf "$BUILD_DIR"
rm -f "$TEST_RESOURCE"
mkdir -p "$BUILD_DIR"

echo "==> Building unit tests"
if ! lazbuild --ws=qt6 --build-mode=qt6 "$PROJECT_FILE" \
  >"$BUILD_LOG" 2>&1; then
  cat "$BUILD_LOG"
  echo "Compilation failed: entimetests"
  exit 1
fi

if [[ ! -x "$TEST_BINARY" ]]; then
  echo "Error: test binary not found after build: $TEST_BINARY"
  exit 1
fi

echo "==> Running unit tests"
"$TEST_BINARY" --all --format=plain

echo "All tests passed."
