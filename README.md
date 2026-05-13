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
- `versions.txt`

`TestLib.xcframework` contains iOS device and simulator slices. The simulator slice is `ios-arm64_x86_64-simulator`; it is intentionally separate from the device `ios-arm64` slice because simulator `arm64` and device `arm64` are different platforms.

The EarlGrey test headers are packaged inside `TestLib.xcframework` in each slice. They include both the original EarlGrey directory layout and a flat header layer. EarlGrey public headers mix imports such as `"TestLib/EarlGrey.h"`, `"AppFramework/Action/GREYAction.h"`, and unqualified imports like `"GREYDiagnosable.h"`, so both layouts are required for Swift bridging headers. There is no separate top-level headers artifact to copy into consumers.

## Package Release Asset

```bash
scripts/package_release.sh
```

This creates a zip and SHA-256 file under `dist/`, ready to attach to a GitHub Release.

## Publish From Local

You can publish directly with the GitHub CLI:

```bash
scripts/publish_github_release.sh
```

If the local git remote does not resolve to the target GitHub repository, pass it explicitly:

```bash
scripts/publish_github_release.sh --repo OWNER/earlgrey-binaries
```

By default, the release tag is the EarlGrey version declared by the pinned source (`2.2.2` for the current pin). Pass `--tag` only when you intentionally need a different release name. Use `--skip-build` to publish the existing files in `artifacts/` and `dist/` without rebuilding.

## Bitrise Shape

A Bitrise workflow can run these steps:

```bash
scripts/publish_github_release.sh --repo OWNER/earlgrey-binaries
```

Configure `GITHUB_TOKEN` or `GH_TOKEN` in Bitrise with permission to create releases and upload assets. If you want Bitrise to build on every commit but publish only on tags, gate this step with Bitrise's tag trigger or a small shell condition around `BITRISE_GIT_TAG`.

## Consumer Notes

The expected consumer layout is:

```text
Libs/EarlGrey2/
  AppFramework.xcframework
  TestLib.xcframework
  versions.txt
```

The MultiviewTV Tuist integration links `AppFramework.xcframework` into the EarlGrey host app and `TestLib.xcframework` into the EarlGrey UI test bundle.
