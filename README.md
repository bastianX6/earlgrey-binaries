# EarlGrey2 Binaries

This repository builds pinned EarlGrey2 artifacts as XCFrameworks so app repositories can download fixed release assets instead of compiling EarlGrey during project generation.

## Pinned Sources

The source refs live in [config/earlgrey.env](config/earlgrey.env):

- `EARLGREY_REPOSITORY_URL`: upstream EarlGrey repository.
- `EARLGREY_REF`: commit from the `earlgrey2` branch.
- `EDISTANTOBJECT_REF`: eDistantObject commit used by that EarlGrey checkout.

The current pins match the MultiviewTV integration spike that was verified locally.

## Local Build

```bash
scripts/build_xcframeworks.sh --force
```

Outputs are written to `artifacts/EarlGrey2/`:

- `AppFramework.xcframework`
- `TestLib.xcframework`
- `CommonLib.xcframework`
- `versions.txt`

`TestLib.xcframework` and `CommonLib.xcframework` contain iOS device and simulator slices. The simulator slice is `ios-arm64_x86_64-simulator`; it is intentionally separate from the device `ios-arm64` slice because simulator `arm64` and device `arm64` are different platforms.

The static-library headers include both the original EarlGrey directory layout and a flat header layer. EarlGrey public headers mix imports such as `"TestLib/EarlGrey.h"`, `"AppFramework/Action/GREYAction.h"`, and unqualified imports like `"GREYDiagnosable.h"`, so both layouts are required for Swift bridging headers.

## Package Release Asset

```bash
scripts/package_release.sh
```

This creates a zip and SHA-256 file under `dist/`, ready to attach to a GitHub Release.

## Bitrise Shape

A Bitrise workflow can run these steps:

```bash
scripts/build_xcframeworks.sh --force
scripts/package_release.sh
```

Then upload `dist/earlgrey2-xcframeworks-*.zip` and the matching `.sha256` file to the GitHub Release. Keep release publishing outside this script so CI credentials and release policy stay in Bitrise/GitHub configuration.

## Consumer Notes

The expected consumer layout is:

```text
Libs/EarlGrey2/
  AppFramework.xcframework
  TestLib.xcframework
  CommonLib.xcframework
  versions.txt
```

The MultiviewTV Tuist integration currently links `AppFramework.xcframework` into the EarlGrey host app and `TestLib.xcframework` into the EarlGrey UI test bundle.
