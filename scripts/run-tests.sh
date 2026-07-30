#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"
BUILD_DIR="$TESTS_DIR/.test_build"

if ! command -v fpc >/dev/null 2>&1; then
  echo "Error: fpc is not installed or not in PATH."
  exit 1
fi

FPC_TARGET="$(fpc -iTP)-$(fpc -iTO)"
LAZUTILS_UNITS_DIR="${LAZUTILS_UNITS_DIR:-/usr/lib/lazarus/components/lazutils/lib/$FPC_TARGET}"
CHSDET_UNITS_DIR="${CHSDET_UNITS_DIR:-$HOME/.lazarus/onlinepackagemanager/packages/chsdet/lib/$FPC_TARGET}"

if [[ ! -d "$TESTS_DIR" ]]; then
  echo "Error: tests directory not found: $TESTS_DIR"
  exit 1
fi

if [[ ! -d "$LAZUTILS_UNITS_DIR" ]]; then
  echo "Error: LazUtils units directory not found: $LAZUTILS_UNITS_DIR"
  exit 1
fi

if [[ ! -d "$CHSDET_UNITS_DIR" ]]; then
  echo "Error: chsdet units directory not found: $CHSDET_UNITS_DIR"
  exit 1
fi

mapfile -t TEST_RUNNERS < <(find "$TESTS_DIR" -maxdepth 1 -type f -name '*.lpr' | sort)

if [[ ${#TEST_RUNNERS[@]} -eq 0 ]]; then
  echo "No test runners (*.lpr) found in $TESTS_DIR"
  exit 1
fi

cleanup() {
  rm -rf "$BUILD_DIR"
}

trap cleanup EXIT
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

failures=0

for runner in "${TEST_RUNNERS[@]}"; do
  test_name="$(basename "$runner" .lpr)"
  test_bin="$BUILD_DIR/$test_name"

  echo "==> Compiling $test_name"
  if ! fpc -Fu"$ROOT_DIR" -Fu"$TESTS_DIR" \
    -Fu"$LAZUTILS_UNITS_DIR" -Fu"$CHSDET_UNITS_DIR" \
    -FU"$BUILD_DIR" -FE"$BUILD_DIR" "$runner" >/dev/null; then
    echo "Compilation failed: $test_name"
    failures=$((failures + 1))
    continue
  fi

  echo "==> Running $test_name"
  if ! "$test_bin" --all --format=plain; then
    failures=$((failures + 1))
  fi
  echo
done

if [[ $failures -ne 0 ]]; then
  echo "Finished with $failures failing test runner(s)."
  exit 1
fi

echo "All tests passed."
