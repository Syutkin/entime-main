#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/benchmark-sql.sh [participants=1000] [stages=8] [repeats=3]
# Schema expansion: scripts/benchmark-sql.sh schema [participants=1000]
# Category read plans: scripts/benchmark-sql.sh plans [participants=5000] [stages=32]
# Fresh in-memory fixtures; excludes UI, fixture preparation and disk latency.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/tests/.test_build"
mkdir -p "$BUILD_DIR"
if ! lazbuild --ws=qt6 "$ROOT_DIR/tests/sqlbenchmark.lpi" \
  >"$BUILD_DIR/sqlbenchmark-build.log" 2>&1; then
  cat "$BUILD_DIR/sqlbenchmark-build.log" >&2
  exit 1
fi
"$BUILD_DIR/sqlbenchmark" "$@"
