#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/entime.lpi"
PACKAGE_FILE="$ROOT_DIR/packages/myforks/myforks.lpk"
LANGUAGE_DIR="$ROOT_DIR/languages"
POT_FILE="$LANGUAGE_DIR/entime.pot"
UPDATE_PO_FILES="$(command -v updatepofiles || true)"

if ! command -v lazbuild >/dev/null 2>&1; then
  echo "Error: lazbuild is not installed or not in PATH."
  exit 1
fi

if ! command -v fpc >/dev/null 2>&1; then
  echo "Error: fpc is not installed or not in PATH."
  exit 1
fi

if [[ -z "$UPDATE_PO_FILES" ]]; then
  for candidate in \
    /usr/lib/lazarus/tools/updatepofiles \
    /usr/share/lazarus/tools/updatepofiles; do
    if [[ -x "$candidate" ]]; then
      UPDATE_PO_FILES="$candidate"
      break
    fi
  done
fi

if [[ -z "$UPDATE_PO_FILES" ]]; then
  echo "Error: the Lazarus updatepofiles utility was not found."
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Error: project file is missing: $PROJECT_FILE"
  exit 1
fi

if [[ ! -f "$PACKAGE_FILE" ]]; then
  echo "Error: local package file is missing: $PACKAGE_FILE"
  exit 1
fi

mkdir -p "$LANGUAGE_DIR"

echo "==> Registering the local package"
lazbuild --add-package-link "$PACKAGE_FILE"

echo "==> Updating Entime translation catalogues"
lazbuild --no-write-project --ws=qt6 --build-mode=qt6 "$PROJECT_FILE"

TARGET_PLATFORM="$(fpc -iTP)-$(fpc -iTO)"
RSJ_FILE="$ROOT_DIR/build/units/$TARGET_PLATFORM/qt6/i18n.rsj"

if [[ ! -s "$RSJ_FILE" ]]; then
  echo "Error: Lazarus did not generate a non-empty resource file: $RSJ_FILE"
  exit 1
fi

RESOURCE_FILES=("$RSJ_FILE")
while IFS= read -r -d '' resource_file; do
  RESOURCE_FILES+=("$resource_file")
done < <(find "$ROOT_DIR/src" -type f -name '*.lrj' -print0)

"$UPDATE_PO_FILES" "${RESOURCE_FILES[@]}" "$POT_FILE"

for catalogue in "$POT_FILE" "$LANGUAGE_DIR"/entime.*.po; do
  [[ -f "$catalogue" ]] || continue
  while [[ "$(tail -c 2 "$catalogue" | wc -l)" -eq 2 ]]; do
    truncate -s -1 "$catalogue"
  done
done

if [[ ! -s "$POT_FILE" ]]; then
  echo "Error: Lazarus did not generate a non-empty catalogue: $POT_FILE"
  exit 1
fi

echo "Translation catalogues updated in: $LANGUAGE_DIR"
