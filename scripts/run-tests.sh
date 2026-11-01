#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"
PROJECT_FILE="$TESTS_DIR/entimetests.lpi"
BUILD_DIR="$TESTS_DIR/.test_build"
TEST_BINARY="$BUILD_DIR/entimetests"
TEST_RESOURCE="$TESTS_DIR/entimetests.res"
BUILD_LOG="$BUILD_DIR/lazbuild.log"
LAZARUS_TEST_CONFIG="$BUILD_DIR/lazarus-config"
LAZARUS_ARGS=(--ws=qt6 --pcp="$LAZARUS_TEST_CONFIG" --scp="${LAZARUS_SECONDARY_CONFIG:-$HOME/.lazarus}")

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
mkdir -p "$LAZARUS_TEST_CONFIG"

echo "==> Building unit tests"
lazbuild "${LAZARUS_ARGS[@]}" --add-package-link \
  "$ROOT_DIR/packages/simpledelphible/SimpleDelphiBLEPackage.lpk" \
  "$ROOT_DIR/packages/lazble/lazble.lpk"
if ! lazbuild "${LAZARUS_ARGS[@]}" --no-write-project --build-mode=qt6 "$PROJECT_FILE" \
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
cp "$ROOT_DIR/packages/simpledelphible/lib/linux-x64/libsimplecble.so" "$BUILD_DIR/"
ENTIME_ROOT="$ROOT_DIR" "$TEST_BINARY" --all --format=plain

echo "All tests passed."
