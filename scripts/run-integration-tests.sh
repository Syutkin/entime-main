#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests/integration"
PROJECT_FILE="$TESTS_DIR/entime_integration_tests.lpi"
BUILD_DIR="$TESTS_DIR/.test_build"
TEST_BINARY="$BUILD_DIR/entime_integration_tests"

if ! command -v lazbuild >/dev/null 2>&1; then
  echo "Error: lazbuild is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Error: integration test project not found: $PROJECT_FILE"
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/home" "$BUILD_DIR/xdg-config"

echo "==> Building integration tests"
lazbuild --ws=qt6 --build-mode=qt6 "$PROJECT_FILE" >/dev/null

if [[ ! -x "$TEST_BINARY" ]]; then
  echo "Error: test binary not found after build: $TEST_BINARY"
  exit 1
fi

echo "==> Running integration tests (headless)"
if command -v xvfb-run >/dev/null 2>&1; then
  ENTIME_ROOT="$ROOT_DIR" HOME="$BUILD_DIR/home" \
    XDG_CONFIG_HOME="$BUILD_DIR/xdg-config" \
    xvfb-run -a "$TEST_BINARY" --all --format=plain
else
  echo "Warning: xvfb-run not found, using QT_QPA_PLATFORM=offscreen fallback."
  ENTIME_ROOT="$ROOT_DIR" HOME="$BUILD_DIR/home" \
    XDG_CONFIG_HOME="$BUILD_DIR/xdg-config" QT_QPA_PLATFORM=offscreen \
    "$TEST_BINARY" --all --format=plain
fi
