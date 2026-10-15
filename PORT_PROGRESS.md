# Amnesia iOS Port Progress

Last updated: 2026-10-15

## Verified baseline

- Repository: `bentleylazanik-gif/amnesia-ios-poc`, branch `main`; last committed baseline: `548027b` (`Generate Info.plist for HPL2 CRC tests`). No changes from this session have been committed or pushed.
- The owner reports the SDL3 3.4.18 app builds, signs, installs, and runs on an iPhone 11 Pro; its blue screen changes to red when tapped. Its source and target are preserved.
- GitHub Actions run `38686449022` for `548027b` succeeded: HPL2 CRC compiled for the iOS device SDK and the CRC XCTest passed on an iOS Simulator. This was not a physical-device HPL2 test.
- Upstream Amnesia is pinned to `acc95cdedd6c94db89dc924eb9afa23185df562f`. No game assets are present or included.

## Current milestone: Quaternion transforms

Added an uncommitted HPL2 `Quaternion.cpp` smoke test after CRC. Quaternion rotation and matrix conversion are used in HPL2 camera/object transform paths. The deterministic test checks a 90-degree Z rotation, composing two turns, and quaternion/matrix round-tripping. This is a math component test, not an HPL2 boot, renderer integration, or Amnesia scene run.

## Uncommitted changes awaiting owner review

- `.github/workflows/ios-sdl-poc.yml`: sparse-checkout/stage only the pinned CRC and Quaternion source/include closure; compile both static libraries for the iOS device SDK; run both XCTest methods on an iPhone Simulator.
- `ios-sdl-poc/project.yml`: add a separate `HPL2Quaternion` static-library target to the existing HPL2 math smoke scheme; preserve the SDL app scheme and target.
- `ios-sdl-poc/Tests/HPL2CRCTests/HPL2CRCTests.mm`: preserve CRC tests and add rotation/composition/matrix-round-trip assertions.
- `ios-sdl-poc/README.md`: document the quaternion component, pinned source dependencies, and Simulator-only validation.
- `PORT_PROGRESS.md`: this recovery log.

`SDLTouchPoC` source is unchanged. No full engine, dependency archive, desktop binaries, FBX SDK, or game assets are staged in the repository. Workflow sparse-checkout stages 18 selected upstream source/header files in ignored build scratch only.

## Attempts and results

- The pinned upstream source was inspected. `Quaternion.cpp` includes `Math.h` and `LowLevelSystem.h`, but uses no platform APIs or third-party functions at link time. `g++ -MM` found a 16-header HPL2 include closure across math, graphics-type declarations, and system declarations.
- Ran the workflow's sparse staging logic in a temporary directory: it checked out exactly 18 source/header files at the pinned SHA, with no dependencies or assets.
- Compiled the pinned CRC and Quaternion implementations together with the Linux host compiler. CRC `0x89A1897F`, Z-axis axis-angle rotation, two-turn composition, and matrix round-trip passed. This is a host check only, not an iOS build.
- Workflow and XcodeGen YAML parse; the test host plist parses; all inline workflow bash blocks and the README shell block pass syntax checks; `git diff --check` passes. The existing SDL device/simulator build commands are unchanged.
- AQ is Linux without `xcodebuild`, XcodeGen, or `xcrun`. GitHub Actions has not run these uncommitted quaternion changes because they have not been pushed. Do not claim an iOS device or Simulator result for Quaternion yet.
- An initial host harness used `cVector3f`/`cMatrixf` aliases not declared by `Quaternion.h` alone and failed; it was corrected to use `cVector3<float>`/`cMatrix<float>`. A later temporary compile command had a path typo; the corrected test passed.

## Recovery

- Worktree: `/tmp/tmp.VZQPoiHQ4P`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Last known committed and Actions-passing baseline: `548027b` / run `38686449022`.
- Current branch should still be `main`, with the five paths listed above uncommitted. Do not reset, clean, commit, or push without owner approval. Preserve `ios-sdl-poc/Sources/main.c`, the CRC test, and the pinned source logic.

## Next action

Owner reviews the diff first. After approval, push and inspect Actions output for (1) arm64 iOS device-SDK compilation and (2) both Simulator XCTest methods. If they pass, the next useful graphics-directed milestone is HPL2 matrix/frustum or camera view-projection math, followed by a minimal iOS graphics backend test. The current changes still do not boot HPL2 or render an Amnesia scene.
