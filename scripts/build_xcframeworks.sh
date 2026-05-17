#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/build_xcframeworks.sh [--force] [--source-dir <path>] [--output-dir <path>] [--skip-checkout]

Builds pinned EarlGrey2 sources into XCFramework artifacts:
  AppFramework.xcframework
  TestLib.xcframework
  AppFramework-tvOS.xcframework
  TestLib-tvOS.xcframework

The default source checkout path is sources/EarlGrey2 and the default output
path is artifacts/EarlGrey2.
USAGE
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/sources/EarlGrey2"
OUTPUT_DIR="$ROOT_DIR/artifacts/EarlGrey2"
VERSION_FILE="$ROOT_DIR/VERSION"
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
TVOS_APP_XCFRAMEWORK="$OUTPUT_DIR/AppFramework-tvOS.xcframework"
TVOS_TEST_XCFRAMEWORK="$OUTPUT_DIR/TestLib-tvOS.xcframework"
HEADERS_DIR="$OUTPUT_DIR/.headers"
EARLGREY_TVOS_DEPLOYMENT_TARGET="${EARLGREY_TVOS_DEPLOYMENT_TARGET:-13.0}"

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

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Missing release version file: $VERSION_FILE" >&2
  exit 1
fi

release_version="$(awk 'NF { print $1; exit }' "$VERSION_FILE")"
if [[ -z "$release_version" ]]; then
  echo "Release version file is empty: $VERSION_FILE" >&2
  exit 1
fi

if [[ "$FORCE" != true && -d "$APP_XCFRAMEWORK" && -d "$TEST_XCFRAMEWORK" && \
      -d "$TVOS_APP_XCFRAMEWORK" && -d "$TVOS_TEST_XCFRAMEWORK" ]]; then
  echo "EarlGrey2 XCFrameworks already exist at '$OUTPUT_DIR'. Use --force to rebuild."
  exit 0
fi

IOS_SIM_BUILD_DIR="$SOURCE_DIR/build/Debug-iphonesimulator"
IOS_DEVICE_BUILD_DIR="$SOURCE_DIR/build/Debug-iphoneos"
TVOS_SIM_BUILD_DIR="$SOURCE_DIR/build/Debug-appletvsimulator"
COMMON_OTHER_CFLAGS='$(inherited) -Wno-error=sign-conversion -Wno-error=implicit-int-float-conversion'

build_for_sdk() {
  local sdk="$1"
  local build_app_framework="${2:-true}"
  local extra_build_settings=()

  if [[ "$sdk" == appletv* ]]; then
    extra_build_settings+=(TVOS_DEPLOYMENT_TARGET="$EARLGREY_TVOS_DEPLOYMENT_TARGET")
  fi

  if [[ "$build_app_framework" == true ]]; then
    echo "Building EarlGrey2 AppFramework for $sdk..."
    local app_build_args=(
      xcodebuild
      -project "$SOURCE_DIR/EarlGrey.xcodeproj" \
      -target AppFramework \
      -sdk "$sdk" \
      -configuration Debug
    )
    if [[ ${#extra_build_settings[@]} -gt 0 ]]; then
      app_build_args+=("${extra_build_settings[@]}")
    fi
    app_build_args+=(OTHER_CFLAGS="$COMMON_OTHER_CFLAGS" build)
    "${app_build_args[@]}" | xcbeautify
  else
    echo "Skipping EarlGrey2 AppFramework for $sdk: AppleTVOS SDK does not provide IOKit.framework."
  fi

  echo "Building EarlGrey2 TestLib for $sdk..."
  local test_build_args=(
    xcodebuild
    -project "$SOURCE_DIR/EarlGrey.xcodeproj" \
    -target TestLib \
    -sdk "$sdk" \
    -configuration Debug
  )
  if [[ ${#extra_build_settings[@]} -gt 0 ]]; then
    test_build_args+=("${extra_build_settings[@]}")
  fi
  test_build_args+=(OTHER_CFLAGS="$COMMON_OTHER_CFLAGS" build)
  "${test_build_args[@]}" | xcbeautify
}

build_for_sdk iphonesimulator
build_for_sdk iphoneos
build_for_sdk appletvsimulator

for required in \
  "$IOS_SIM_BUILD_DIR/AppFramework.framework" \
  "$IOS_DEVICE_BUILD_DIR/AppFramework.framework" \
  "$IOS_SIM_BUILD_DIR/libTestLib.a" \
  "$IOS_DEVICE_BUILD_DIR/libTestLib.a" \
  "$IOS_SIM_BUILD_DIR/libCommonLib.a" \
  "$IOS_DEVICE_BUILD_DIR/libCommonLib.a" \
  "$TVOS_SIM_BUILD_DIR/AppFramework.framework" \
  "$TVOS_SIM_BUILD_DIR/libTestLib.a" \
  "$TVOS_SIM_BUILD_DIR/libCommonLib.a"; do
  if [[ ! -e "$required" ]]; then
    echo "Missing built EarlGrey2 artifact: $required" >&2
    exit 1
  fi
done

rm -rf \
  "$APP_XCFRAMEWORK" \
  "$TEST_XCFRAMEWORK" \
  "$TVOS_APP_XCFRAMEWORK" \
  "$TVOS_TEST_XCFRAMEWORK" \
  "$OUTPUT_DIR/CommonLib.xcframework" \
  "$OUTPUT_DIR/Headers" \
  "$HEADERS_DIR"
mkdir -p "$OUTPUT_DIR" "$HEADERS_DIR/TestLib"

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

xcodebuild -create-xcframework \
  -framework "$IOS_SIM_BUILD_DIR/AppFramework.framework" \
  -framework "$IOS_DEVICE_BUILD_DIR/AppFramework.framework" \
  -output "$APP_XCFRAMEWORK" | xcbeautify

xcodebuild -create-xcframework \
  -library "$IOS_SIM_BUILD_DIR/libTestLib.a" -headers "$HEADERS_DIR/TestLib" \
  -library "$IOS_DEVICE_BUILD_DIR/libTestLib.a" -headers "$HEADERS_DIR/TestLib" \
  -output "$TEST_XCFRAMEWORK" | xcbeautify

xcodebuild -create-xcframework \
  -framework "$TVOS_SIM_BUILD_DIR/AppFramework.framework" \
  -output "$TVOS_APP_XCFRAMEWORK" | xcbeautify

xcodebuild -create-xcframework \
  -library "$TVOS_SIM_BUILD_DIR/libTestLib.a" -headers "$HEADERS_DIR/TestLib" \
  -output "$TVOS_TEST_XCFRAMEWORK" | xcbeautify

rm -rf "$HEADERS_DIR"

earlgrey_commit="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
earlgrey_version="$(awk -F'"' '/s\.version/ { print $2; exit }' "$SOURCE_DIR/EarlGreyTest.podspec")"
if [[ -z "$earlgrey_version" ]]; then
  earlgrey_version="$(git -C "$SOURCE_DIR" describe --tags --abbrev=0)"
fi

cat > "$OUTPUT_DIR/versions.txt" <<VERSIONS
ReleaseVersion: $release_version
EarlGrey2: $earlgrey_commit
EarlGrey2Version: $earlgrey_version
eDistantObject: $(git -C "$SOURCE_DIR/Submodules/eDistantObject" rev-parse HEAD)
tvOSDeploymentTarget: $EARLGREY_TVOS_DEPLOYMENT_TARGET
tvOSDeviceSlices: unavailable; EarlGrey AppFramework links IOKit.framework, which is not present in the AppleTVOS SDK
VERSIONS

echo "EarlGrey2 XCFrameworks written to '$OUTPUT_DIR'."
