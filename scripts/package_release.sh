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
SOURCE_DIR="$ROOT_DIR/sources/EarlGrey2"
VERSION_FILE="$ROOT_DIR/VERSION"

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

for required in \
  AppFramework.xcframework \
  TestLib.xcframework \
  AppFramework-tvOS.xcframework \
  TestLib-tvOS.xcframework \
  versions.txt; do
  if [[ ! -e "$ARTIFACTS_DIR/$required" ]]; then
    echo "Missing artifact: $ARTIFACTS_DIR/$required" >&2
    exit 1
  fi
done

mkdir -p "$DIST_DIR"
release_version="$(awk '/^ReleaseVersion:/ { print $2 }' "$ARTIFACTS_DIR/versions.txt")"
if [[ -z "$release_version" && -f "$VERSION_FILE" ]]; then
  release_version="$(awk 'NF { print $1; exit }' "$VERSION_FILE")"
fi
if [[ -z "$release_version" && -f "$SOURCE_DIR/EarlGreyTest.podspec" ]]; then
  release_version="$(awk -F'"' '/s\.version/ { print $2; exit }' "$SOURCE_DIR/EarlGreyTest.podspec")"
fi
if [[ -z "$release_version" ]]; then
  release_version="$(awk '/^EarlGrey2:/ { print $2 }' "$ARTIFACTS_DIR/versions.txt")"
fi
archive_name="earlgrey2-xcframeworks-${release_version}.zip"
archive_path="$DIST_DIR/$archive_name"

rm -f "$archive_path"
(
  cd "$(dirname "$ARTIFACTS_DIR")"
  zip -qry "$archive_path" "$(basename "$ARTIFACTS_DIR")"
)

shasum -a 256 "$archive_path" > "$archive_path.sha256"

echo "$archive_path"
echo "$archive_path.sha256"
