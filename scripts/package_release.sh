#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/package_release.sh [--artifacts-dir <path>] [--dist-dir <path>]

Creates a zip file suitable for a GitHub Release from the generated EarlGrey2
XCFrameworks. Defaults:
  artifacts-dir: artifacts/EarlGrey2
  dist-dir: dist
USAGE
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/artifacts/EarlGrey2"
DIST_DIR="$ROOT_DIR/dist"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifacts-dir)
      ARTIFACTS_DIR="$2"
      shift 2
      ;;
    --dist-dir)
      DIST_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for required in AppFramework.xcframework TestLib.xcframework versions.txt; do
  if [[ ! -e "$ARTIFACTS_DIR/$required" ]]; then
    echo "Missing artifact: $ARTIFACTS_DIR/$required" >&2
    exit 1
  fi
done

mkdir -p "$DIST_DIR"
earlgrey_ref="$(awk '/^EarlGrey2:/ { print $2 }' "$ARTIFACTS_DIR/versions.txt")"
archive_name="earlgrey2-xcframeworks-${earlgrey_ref}.zip"
archive_path="$DIST_DIR/$archive_name"

rm -f "$archive_path"
(
  cd "$(dirname "$ARTIFACTS_DIR")"
  zip -qry "$archive_path" "$(basename "$ARTIFACTS_DIR")"
)

shasum -a 256 "$archive_path" > "$archive_path.sha256"

echo "$archive_path"
echo "$archive_path.sha256"
