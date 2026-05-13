#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/publish_github_release.sh --tag <tag> [--title <title>] [--repo <owner/name>] [--draft] [--prerelease] [--skip-build]

Builds and packages the EarlGrey2 XCFrameworks, then uploads the zip and
SHA-256 file to a GitHub Release using the GitHub CLI.

Environment:
  GITHUB_TOKEN or GH_TOKEN must be available when auth is not already configured.
USAGE
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TAG=""
TITLE=""
REPO=""
DRAFT=false
PRERELEASE=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="$2"
      shift 2
      ;;
    --title)
      TITLE="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --draft)
      DRAFT=true
      shift
      ;;
    --prerelease)
      PRERELEASE=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
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

if [[ -z "$TAG" ]]; then
  echo "Missing --tag." >&2
  usage >&2
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required: https://cli.github.com" >&2
  exit 1
fi

if [[ "$SKIP_BUILD" != true ]]; then
  "$ROOT_DIR/scripts/build_xcframeworks.sh" --force
fi

package_output="$("$ROOT_DIR/scripts/package_release.sh")"
archive_path="$(printf '%s\n' "$package_output" | sed -n '1p')"
checksum_path="$(printf '%s\n' "$package_output" | sed -n '2p')"

if [[ -z "$archive_path" || -z "$checksum_path" ]]; then
  echo "Could not resolve packaged release assets." >&2
  printf '%s\n' "$package_output" >&2
  exit 1
fi

if [[ -z "$TITLE" ]]; then
  TITLE="$TAG"
fi

release_notes="$(mktemp)"
trap 'rm -f "$release_notes"' EXIT
cat > "$release_notes" <<NOTES
EarlGrey2 XCFrameworks.

$(cat "$ROOT_DIR/artifacts/EarlGrey2/versions.txt")
NOTES

gh_args=(release create "$TAG" "$archive_path" "$checksum_path" --title "$TITLE" --notes-file "$release_notes")
if [[ -n "$REPO" ]]; then
  gh_args+=(--repo "$REPO")
fi
if [[ "$DRAFT" == true ]]; then
  gh_args+=(--draft)
fi
if [[ "$PRERELEASE" == true ]]; then
  gh_args+=(--prerelease)
fi

gh "${gh_args[@]}"
