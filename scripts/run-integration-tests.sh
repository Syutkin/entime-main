#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests/integration"
PROJECT_FILE="$TESTS_DIR/entimeintegrationtests.lpi"
BUILD_DIR="$TESTS_DIR/.test_build"
TEST_BINARY="$BUILD_DIR/entimeintegrationtests"
SOCAT_LOG="$BUILD_DIR/socat.log"
LAZARUS_TEST_CONFIG="$BUILD_DIR/lazarus-config"
LAZARUS_SECONDARY_CONFIG="${LAZARUS_SECONDARY_CONFIG:-$HOME/.lazarus}"
SOCAT_PID=""
SERIAL_DEVICE=""
SERIAL_PEER=""
TEST_ARGS=(--all --format=plain)
if [[ -n "${ENTIME_TEST_SUITE:-}" ]]; then
  TEST_ARGS=(--suite="$ENTIME_TEST_SUITE" --format=plain)
fi
TEST_TIMEOUT="${ENTIME_TEST_TIMEOUT_SECONDS:-180}s"

cleanup() {
  if [[ -n "$SOCAT_PID" ]]; then
    kill "$SOCAT_PID" 2>/dev/null || true
    for _ in $(seq 1 50); do
      if ! kill -0 "$SOCAT_PID" 2>/dev/null; then
        wait "$SOCAT_PID" 2>/dev/null || true
        return
      fi
      sleep 0.1
    done
    kill -KILL "$SOCAT_PID" 2>/dev/null || true
    wait "$SOCAT_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT

if ! command -v lazbuild >/dev/null 2>&1; then
  echo "Error: lazbuild is not installed or not in PATH."
  exit 1
fi

if ! command -v socat >/dev/null 2>&1; then
  echo "Error: socat is required for the virtual serial-port integration test but is not installed or not in PATH."
  exit 1
fi

if ! command -v timeout >/dev/null 2>&1; then
  echo "Error: timeout is required to guard against a blocked GUI event loop."
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Error: integration test project not found: $PROJECT_FILE"
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/home" "$BUILD_DIR/xdg-config"
mkdir -p "$LAZARUS_TEST_CONFIG"

echo "==> Building integration tests"
lazbuild --ws=qt6 --pcp="$LAZARUS_TEST_CONFIG" --scp="$LAZARUS_SECONDARY_CONFIG" \
  --add-package-link "$ROOT_DIR/packages/myforks/myforks.lpk" \
  "$ROOT_DIR/packages/simpledelphible/SimpleDelphiBLEPackage.lpk" \
  "$ROOT_DIR/packages/lazble/lazble.lpk" "$ROOT_DIR/packages/lazble/lazblelcl.lpk"
if ! lazbuild --pcp="$LAZARUS_TEST_CONFIG" --scp="$LAZARUS_SECONDARY_CONFIG" \
  --ws=qt6 --no-write-project --build-mode=qt6 "$PROJECT_FILE" >"$BUILD_DIR/lazbuild.log" 2>&1; then
  cat "$BUILD_DIR/lazbuild.log"
  exit 1
fi

if [[ ! -x "$TEST_BINARY" ]]; then
  echo "Error: test binary not found after build: $TEST_BINARY"
  exit 1
fi

cp "$ROOT_DIR/packages/simpledelphible/lib/linux-x64/libsimplecble.so" "$BUILD_DIR/"

socat -d -d pty,raw,echo=0 pty,raw,echo=0 2>"$SOCAT_LOG" &
SOCAT_PID=$!
for _ in $(seq 1 50); do
  mapfile -t SERIAL_PTYS < <(sed -n 's/.*PTY is //p' "$SOCAT_LOG")
  if [[ ${#SERIAL_PTYS[@]} -ge 2 ]]; then
    SERIAL_DEVICE="${SERIAL_PTYS[0]}"
    SERIAL_PEER="${SERIAL_PTYS[1]}"
    break
  fi
  sleep 0.1
done
if [[ -z "$SERIAL_DEVICE" || -z "$SERIAL_PEER" ]]; then
  echo "Error: socat did not create the virtual serial pair."
  exit 1
fi

echo "==> Running integration tests (headless)"
if command -v xvfb-run >/dev/null 2>&1; then
  ENTIME_ROOT="$ROOT_DIR" HOME="$BUILD_DIR/home" \
    XDG_CONFIG_HOME="$BUILD_DIR/xdg-config" \
    ENTIME_SERIAL_DEVICE="$SERIAL_DEVICE" ENTIME_SERIAL_PEER="$SERIAL_PEER" \
    timeout --foreground --kill-after=5s "$TEST_TIMEOUT" \
    xvfb-run -a "$TEST_BINARY" "${TEST_ARGS[@]}"
else
  echo "Warning: xvfb-run not found, using QT_QPA_PLATFORM=offscreen fallback."
  ENTIME_ROOT="$ROOT_DIR" HOME="$BUILD_DIR/home" \
    XDG_CONFIG_HOME="$BUILD_DIR/xdg-config" \
    ENTIME_SERIAL_DEVICE="$SERIAL_DEVICE" ENTIME_SERIAL_PEER="$SERIAL_PEER" \
    QT_QPA_PLATFORM=offscreen \
    timeout --foreground --kill-after=5s "$TEST_TIMEOUT" \
    "$TEST_BINARY" "${TEST_ARGS[@]}"
fi
