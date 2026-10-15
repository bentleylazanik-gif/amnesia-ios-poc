# Amnesia iOS Port Progress

Last updated: 2026-10-15

## Verified baseline

- Repository: `bentleylazanik-gif/amnesia-ios-poc`, branch `main`; current remote baseline: `548027b` (`Generate Info.plist for HPL2 CRC tests`).
- The owner reports the standalone SDL3 3.4.18 app builds, signs, installs, and runs on an iPhone 11 Pro; its blue screen changes to red when tapped. Its code is preserved.
- GitHub Actions run `38686449022` for `548027b` passed the CRC XCTest on an iOS Simulator and compiled CRC for the iOS device SDK. It was not an HPL2 physical-device run.
- Upstream source pin: `acc95cdedd6c94db89dc924eb9afa23185df562f`. No commercial game assets are present or included.

## Current milestone: HPL2 quaternion transform math

Add HPL2's real `Quaternion.cpp` after CRC as a math primitive used by camera/object transform paths. XCTest assertions cover a 90-degree Z-axis rotation (X to Y), composing two turns (X to -X), and matrix-to-quaternion-to-matrix consistency. This is not an HPL2 boot or renderer/scene test.

## Proposed changes

- Extend the upstream sparse checkout to the Quaternion implementation plus only its compiler-discovered HPL2 header closure, staged transiently under ignored `EngineSource/`.
- Add an `HPL2Quaternion` static library and quaternion XCTest alongside CRC. The existing `HPL2CRCSmoke` scheme builds both libraries and the Simulator suite.
- Update workflow/README and keep this recovery log current. The SDLTouchPoC target and its source remain unchanged.
- No full engine, desktop dependency binaries, FBX SDK, or game assets are added.

## Attempts and results

- Inspected `Quaternion.cpp` and its headers. `g++ -MM` found a 16-header closure across math, graphics-type, and system declarations. The implementation has no platform API or third-party link dependency.
- The earlier Action run `38741245297` failed before Xcode: its sparse-checkout expansion emitted escaped-slash patterns, so `Color.h` was not materialized. The staging code now passes the path array directly, without prefix substitution. A local rerun against the pinned upstream SHA materialized exactly the 18 selected files (2 implementation files and 16 headers).
- A Linux host compile using the exact staged CRC and Quaternion sources passed: CRC known vector `0x89A1897F`, Quaternion 90-degree rotation, two-turn composition, and matrix round-trip.
- Workflow and project YAML parse, the host Info.plist parses, workflow and README Bash blocks pass `bash -n`, `git diff --check` passes, and the two existing SDL device/Simulator build commands are unchanged.
- AQ has no `xcodebuild`, XcodeGen, or `xcrun`. Thus the current iOS device-SDK build and Simulator XCTest have not run in Actions yet; do not claim those new tests pass. The latest Actions pass remains CRC-only run `38686449022`.

## Recovery and current worktree

- Worktree: `/tmp/tmp.VZQPoiHQ4P`; origin: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Last known committed baseline: `548027b`. The current SDL3 app, CRC test, and pinned-source baseline are preserved.
- Proposed files: `.github/workflows/ios-sdl-poc.yml`, `ios-sdl-poc/project.yml`, `ios-sdl-poc/Tests/HPL2CRCTests/HPL2CRCTests.mm`, `ios-sdl-poc/README.md`, and `PORT_PROGRESS.md`.
- Do not reset or clean. Keep EngineSource staging ignored and transient; do not add proprietary assets.

## Next action

The owner has authorized incremental commits/pushes after validation. Commit and push this tested host-source milestone, then inspect the resulting Actions run for both the `iphoneos` library build and Simulator tests. If they pass, move toward HPL2 matrix/frustum or camera view-projection math, followed by a minimal iOS graphics backend. No HPL2 scene is rendered yet.
