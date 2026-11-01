#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_MODE="${1:-qt6}"
PROJECT_FILE="$ROOT_DIR/entime.lpi"
PACKAGE_FILE="$ROOT_DIR/packages/myforks/myforks.lpk"
LANGUAGE_DIR="$ROOT_DIR/languages"
LAZARUS_CONFIG="$ROOT_DIR/build/lazarus-config"
OUTPUT_DIR="$ROOT_DIR/build/bin/$BUILD_MODE"
TARGET_CPU="${TARGET_CPU:-$(fpc -iTP)}"
TARGET_OS="${TARGET_OS:-$(fpc -iTO)}"
case "$TARGET_CPU-$TARGET_OS" in
  x86_64-linux) NATIVE_PLATFORM=linux-x64; NATIVE_FILES=(libsimplecble.so) ;;
  x86_64-win64) NATIVE_PLATFORM=win64; NATIVE_FILES=(simplecble.dll) ;;
  x86_64-darwin) NATIVE_PLATFORM=macos-x64; NATIVE_FILES=(libsimplecble.dylib) ;;
  aarch64-darwin) NATIVE_PLATFORM=macos-arm64; NATIVE_FILES=(libsimplecble.dylib) ;;
  *) echo "Unsupported LazBle target: $TARGET_CPU-$TARGET_OS" >&2; exit 1 ;;
esac
BINDING_DIR="$ROOT_DIR/packages/simpledelphible"
WIDGETSET=qt6
if [[ "$TARGET_OS" == win64 ]]; then
  WIDGETSET=win32
fi
LAZARUS_ARGS=(--ws="$WIDGETSET" --pcp="$LAZARUS_CONFIG" --scp="${LAZARUS_SECONDARY_CONFIG:-$HOME/.lazarus}")
LAZARUS_ARGS+=(--cpu="$TARGET_CPU" --os="$TARGET_OS")
if [[ -n "${FPC_COMPILER:-}" ]]; then
  LAZARUS_ARGS+=(--compiler="$FPC_COMPILER")
fi

if ! command -v lazbuild >/dev/null 2>&1; then
  echo "Error: lazbuild is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" || ! -f "$PACKAGE_FILE" ]]; then
  echo "Error: project or local package file is missing."
  exit 1
fi

echo "==> Building Entime ($BUILD_MODE)"
mkdir -p "$OUTPUT_DIR" "$LAZARUS_CONFIG"
lazbuild "${LAZARUS_ARGS[@]}" --add-package-link "$PACKAGE_FILE" \
  "$BINDING_DIR/SimpleDelphiBLEPackage.lpk" \
  "$ROOT_DIR/packages/lazble/lazble.lpk" "$ROOT_DIR/packages/lazble/lazblelcl.lpk"
lazbuild "${LAZARUS_ARGS[@]}" --no-write-project --build-mode="$BUILD_MODE" "$PROJECT_FILE"

echo "==> Copying runtime resources"
mkdir -p "$OUTPUT_DIR/languages"
cp -a "$LANGUAGE_DIR/." "$OUTPUT_DIR/languages/"
for template_kind in reports labels; do
  mkdir -p "$OUTPUT_DIR/templates/$template_kind"
  cp -a "$ROOT_DIR/templates/$template_kind/." "$OUTPUT_DIR/templates/$template_kind/"
done
for library in "${NATIVE_FILES[@]}"; do
  cp "$BINDING_DIR/lib/$NATIVE_PLATFORM/$library" "$OUTPUT_DIR/"
done
mkdir -p "$OUTPUT_DIR/licenses/SimpleDelphiBLE"
cp "$BINDING_DIR/LICENSE.md" "$OUTPUT_DIR/licenses/SimpleDelphiBLE/"

echo "Build completed: $OUTPUT_DIR"
