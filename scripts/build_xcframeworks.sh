#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build_xcframeworks.sh [--force] [--source-dir <path>] [--output-dir <path>] [--skip-checkout]

Builds pinned EarlGrey2 sources into XCFramework artifacts:
  AppFramework.xcframework
  TestLib.xcframework
  CommonLib.xcframework

The default source checkout path is sources/EarlGrey2 and the default output
path is artifacts/EarlGrey2.
USAGE
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/sources/EarlGrey2"
OUTPUT_DIR="$ROOT_DIR/artifacts/EarlGrey2"
FORCE=false
SKIP_CHECKOUT=false

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
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --skip-checkout)
      SKIP_CHECKOUT=true
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

APP_XCFRAMEWORK="$OUTPUT_DIR/AppFramework.xcframework"
TEST_XCFRAMEWORK="$OUTPUT_DIR/TestLib.xcframework"
COMMON_XCFRAMEWORK="$OUTPUT_DIR/CommonLib.xcframework"
HEADERS_DIR="$OUTPUT_DIR/Headers"

if [[ "$SKIP_CHECKOUT" != true ]]; then
  checkout_args=(--source-dir "$SOURCE_DIR")
  if [[ "$FORCE" == true ]]; then
    checkout_args+=(--force)
  fi
  "$ROOT_DIR/scripts/checkout_earlgrey.sh" "${checkout_args[@]}"
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Missing EarlGrey2 checkout at $SOURCE_DIR" >&2
  echo "Run scripts/checkout_earlgrey.sh first, or omit --skip-checkout." >&2
  exit 1
fi

if [[ "$FORCE" != true && -d "$APP_XCFRAMEWORK" && -d "$TEST_XCFRAMEWORK" && -d "$COMMON_XCFRAMEWORK" ]]; then
  echo "EarlGrey2 XCFrameworks already exist at '$OUTPUT_DIR'. Use --force to rebuild."
  exit 0
fi

SIM_BUILD_DIR="$SOURCE_DIR/build/Debug-iphonesimulator"
DEVICE_BUILD_DIR="$SOURCE_DIR/build/Debug-iphoneos"
COMMON_OTHER_CFLAGS='$(inherited) -Wno-error=sign-conversion -Wno-error=implicit-int-float-conversion'

build_for_sdk() {
  local sdk="$1"

  echo "Building EarlGrey2 AppFramework for $sdk..."
  xcodebuild \
    -project "$SOURCE_DIR/EarlGrey.xcodeproj" \
    -target AppFramework \
    -sdk "$sdk" \
    -configuration Debug \
    OTHER_CFLAGS="$COMMON_OTHER_CFLAGS" \
    build

  echo "Building EarlGrey2 TestLib for $sdk..."
  xcodebuild \
    -project "$SOURCE_DIR/EarlGrey.xcodeproj" \
    -target TestLib \
    -sdk "$sdk" \
    -configuration Debug \
    OTHER_CFLAGS="$COMMON_OTHER_CFLAGS" \
    build
}

build_for_sdk iphonesimulator
build_for_sdk iphoneos

for required in \
  "$SIM_BUILD_DIR/AppFramework.framework" \
  "$DEVICE_BUILD_DIR/AppFramework.framework" \
  "$SIM_BUILD_DIR/libTestLib.a" \
  "$DEVICE_BUILD_DIR/libTestLib.a" \
  "$SIM_BUILD_DIR/libCommonLib.a" \
  "$DEVICE_BUILD_DIR/libCommonLib.a"; do
  if [[ ! -e "$required" ]]; then
    echo "Missing built EarlGrey2 artifact: $required" >&2
    exit 1
  fi
done

rm -rf "$APP_XCFRAMEWORK" "$TEST_XCFRAMEWORK" "$COMMON_XCFRAMEWORK" "$HEADERS_DIR"
mkdir -p "$OUTPUT_DIR" "$HEADERS_DIR/TestLib" "$HEADERS_DIR/CommonLib"

copy_header_tree() {
  local source_dir="$1"
  local destination_dir="$2"

  mkdir -p "$destination_dir"
  rsync -a --include='*/' --include='*.h' --exclude='*' "$source_dir/" "$destination_dir/"
}

copy_flat_headers() {
  local source_dir="$1"
  local destination_dir="$2"

  find "$source_dir" -type f -name '*.h' -exec cp {} "$destination_dir/" \;
}

copy_earlgrey_headers() {
  local destination_dir="$1"

  mkdir -p "$destination_dir/eDistantObject"

  copy_header_tree "$SOURCE_DIR/TestLib" "$destination_dir/TestLib"
  copy_header_tree "$SOURCE_DIR/CommonLib" "$destination_dir/CommonLib"
  copy_header_tree "$SOURCE_DIR/AppFramework" "$destination_dir/AppFramework"
  copy_header_tree "$SOURCE_DIR/UILib" "$destination_dir/UILib"

  for edo_component in Channel Device DeviceForwarder Measure Service; do
    copy_header_tree \
      "$SOURCE_DIR/Submodules/eDistantObject/$edo_component/Sources" \
      "$destination_dir/eDistantObject"
  done

  copy_flat_headers "$SOURCE_DIR/TestLib" "$destination_dir"
  copy_flat_headers "$SOURCE_DIR/CommonLib" "$destination_dir"
  copy_flat_headers "$SOURCE_DIR/AppFramework" "$destination_dir"
  copy_flat_headers "$SOURCE_DIR/UILib" "$destination_dir"
  copy_flat_headers "$SOURCE_DIR/Submodules/eDistantObject" "$destination_dir"
}

copy_earlgrey_headers "$HEADERS_DIR/TestLib"
rsync -a --delete "$HEADERS_DIR/TestLib/" "$HEADERS_DIR/CommonLib/"

xcodebuild -create-xcframework \
  -framework "$SIM_BUILD_DIR/AppFramework.framework" \
  -framework "$DEVICE_BUILD_DIR/AppFramework.framework" \
  -output "$APP_XCFRAMEWORK"

xcodebuild -create-xcframework \
  -library "$SIM_BUILD_DIR/libTestLib.a" -headers "$HEADERS_DIR/TestLib" \
  -library "$DEVICE_BUILD_DIR/libTestLib.a" -headers "$HEADERS_DIR/TestLib" \
  -output "$TEST_XCFRAMEWORK"

xcodebuild -create-xcframework \
  -library "$SIM_BUILD_DIR/libCommonLib.a" -headers "$HEADERS_DIR/CommonLib" \
  -library "$DEVICE_BUILD_DIR/libCommonLib.a" -headers "$HEADERS_DIR/CommonLib" \
  -output "$COMMON_XCFRAMEWORK"

cat > "$OUTPUT_DIR/versions.txt" <<VERSIONS
EarlGrey2: $(git -C "$SOURCE_DIR" rev-parse HEAD)
eDistantObject: $(git -C "$SOURCE_DIR/Submodules/eDistantObject" rev-parse HEAD)
VERSIONS

echo "EarlGrey2 XCFrameworks written to '$OUTPUT_DIR'."
