# Amnesia iOS Port Progress

Last updated: 2026-10-15

## Verified repository baseline

- Repository: `bentleylazanik-gif/amnesia-ios-poc`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Before the latest work, GitHub `main` was `6f587c6` (`Add HPL2 quaternion smoke test`). That commit contains the SDL3 PoC and CRC/Quaternion test targets.
- The last known passing Actions run before Quaternion was run `38686449022` on `548027b`: CRC compiled for the iOS device SDK and its XCTest passed on an iOS Simulator. It was not a physical-device HPL2 test.
- Actions run `38741245297` on `6f587c6` failed in the upstream sparse-source staging step before Xcode ran. Exact error: `Pinned upstream file is missing: HPL2/core/include/graphics/Color.h`.
- The owner reports that the separate SDL3 3.4.18 app was built, signed, installed, and run on an iPhone 11 Pro; tapping changes its blue screen to red. Its app source is preserved.
- Upstream Amnesia is pinned at `acc95cdedd6c94db89dc924eb9afa23185df562f`. No commercial game assets are included.

## Current milestone: HPL2 quaternion transforms

Keep CRC and add the real `Quaternion.cpp` rotation implementation as a math step toward camera/object transforms. The test covers a 90-degree Z rotation, two-turn composition, and quaternion/matrix round-tripping. This is not HPL2 boot, renderer integration, scene loading, or an Amnesia game run.

## Changes made in this session

- Fixed the sparse-checkout pattern bug: the old Bash prefix substitution produced backslash-prefixed paths, leaving the requested upstream files absent. The workflow now passes repository-relative paths directly and stages only the selected HPL2 math source/header closure.
- Added `HPL2Quaternion` as a separate static library; added quaternion assertions alongside the existing CRC XCTest.
- Updated README and this progress log. Existing SDL3 app source and build steps remain unchanged.
- Local commit `2134862` contains the sparse-checkout correction and quaternion milestone notes. It is currently local/unpushed relative to `origin/main` (which remains `6f587c6`).

## Dependency and test evidence

- `Quaternion.cpp` includes `Math.h` and `LowLevelSystem.h`; a compiler dependency scan found 16 HPL2 headers across math, graphics-type, and system declarations. The implementation has no platform API or external library link references.
- The sparse source staging command was exercised in a temporary directory and checked out exactly 18 upstream files at the pinned SHA (CRC + Quaternion and the header closure), with no desktop dependencies or assets.
- Linux host C++ compilation/execution of the pinned CRC and Quaternion sources passed: CRC `0x89A1897F`, Z-axis rotation, two-turn composition, and matrix round-trip. An initial harness used aliases not declared by `Quaternion.h` alone; correcting it to `cVector3<float>` and `cMatrix<float>` made the test pass. This is host-only evidence, not an iOS build.
- Workflow and project YAML, host plist, Bash syntax, README shell syntax, and `git diff --check` passed. The two existing SDL device/Simulator build command bodies are unchanged.
- The AQ workspace is Linux and lacks `xcodebuild`, XcodeGen, and `xcrun`. The current HPL2 device-SDK build and Simulator XCTest have not run in Actions yet. Do not claim the Quaternion iOS test has passed.

## Recovery and next action

- Worktree: `/tmp/tmp.VZQPoiHQ4P`. Preserve all current files; do not reset or clean.
- Keep `ios-sdl-poc/Sources/main.c`, CRC tests, and `SDLTouchPoC` project target unchanged. `EngineSource/` is ignored scratch; only pinned math files are staged during CI.
- The owner has authorized pushing verified changes. Push local commit `2134862` to run Actions, then inspect the run logs for device-SDK compilation and both Simulator XCTest methods. If they pass, update this log and the next milestone can test matrix/frustum or camera view-projection math before attempting an iOS graphics backend.
- No HPL2 scene has been rendered on Simulator or iPhone. Renderer/platform/resource adaptation and legitimate private game data remain future work.
