#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/checkout_earlgrey.sh [--force] [--source-dir <path>]

Clones EarlGrey2 and pins both EarlGrey and eDistantObject to the refs declared
in config/earlgrey.env. The default checkout path is sources/EarlGrey2.
USAGE
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/earlgrey.env"
SOURCE_DIR="$ROOT_DIR/sources/EarlGrey2"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    --source-dir)
      SOURCE_DIR="$2"
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

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=../config/earlgrey.env
source "$CONFIG_FILE"

if [[ -d "$SOURCE_DIR/.git" && "$FORCE" != true ]]; then
  echo "EarlGrey checkout already exists at '$SOURCE_DIR'. Use --force to recreate it."
else
  rm -rf "$SOURCE_DIR"
  mkdir -p "$(dirname "$SOURCE_DIR")"
  git clone --branch earlgrey2 "$EARLGREY_REPOSITORY_URL" "$SOURCE_DIR"
fi

git -C "$SOURCE_DIR" fetch --tags origin
git -C "$SOURCE_DIR" checkout "$EARLGREY_REF"

if [[ ! -d "$SOURCE_DIR/Submodules/eDistantObject" ]]; then
  (cd "$SOURCE_DIR" && sh Scripts/download_deps.sh)
fi

git -C "$SOURCE_DIR/Submodules/eDistantObject" fetch --tags origin || true
git -C "$SOURCE_DIR/Submodules/eDistantObject" checkout "$EDISTANTOBJECT_REF"

echo "EarlGrey2: $(git -C "$SOURCE_DIR" rev-parse HEAD)"
echo "eDistantObject: $(git -C "$SOURCE_DIR/Submodules/eDistantObject" rev-parse HEAD)"
