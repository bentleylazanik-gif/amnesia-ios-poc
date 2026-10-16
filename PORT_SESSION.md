# Port Session Checkpoint

Updated: 2026-10-16

## Verified checkpoint

- Repository checkout: `/tmp/tmp.VZQPoiHQ4P`, branch `main`, remote `origin` is `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Current committed baseline at recovery: `43f616046a5f6ae9d2c0eb459c0b360222d1ce4b`; local `main` and `origin/main` match. No staged changes were present.
- Latest completed Actions run: `38806244632`, success: https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38806244632
  - Pinned upstream sparse checkout and XcodeGen project generation passed.
  - HPL2 CRC, Quaternion, Math and Metal probe libraries compiled for iOS device SDK (compile only; no device execution).
  - Eight XCTest methods passed on an iOS Simulator, including offscreen Metal triangle pixel readback, resource and math/frame tests.
  - SDL app builds for device and Simulator SDKs, IPA packaging and artifact upload passed.
  - Logs confirm `IOSMetalTriangleProbe.o` compiled under its own probe target and not under the SDLTouchPoC app target. The SDL app glob exclusion is verified in generated build behavior.
  - The Metal probe is an offscreen Simulator test, not visible output, not a physical iPhone test, and not an HPL2 renderer.
- The recovery checks confirmed no active command; run `38806244632` is complete. Current uncommitted changes are the SDL visible-triangle drawing, the SDLMetalVisible UI test/scheme/workflow step, and updated progress/task/session records. YAML, bash, plist, target wiring, host math/resource/frame-clock checks, and `git diff --check` pass; no Xcode binaries are available in this Linux workspace.

## Current local work (uncommitted; preserve)

- `ios-sdl-poc/Sources/main.c`: explicitly selects SDL3's `metal` renderer and draws an original white triangle with `SDL_RenderGeometry`; retains the blue/red touch background, logs the selected renderer, queries logical window size each frame, and handles nonpositive size safely.
- `ios-sdl-poc/Tests/SDLMetalVisibleTests/SDLMetalVisibleTests.m`: UI test launches the SDL app and checks the center screenshot for a bright triangle pixel; it attaches a screenshot on failure/success.
- `ios-sdl-poc/project.yml`: separate SDLMetalVisibleTests UI-test target and scheme; the Metal probe remains excluded from the SDLTouchPoC source glob and is built only in its own test library.
- `.github/workflows/ios-sdl-poc.yml`: a Simulator UI-test step and `.xcresult` upload with `if: always()` are present locally.
- `ios-sdl-poc/Tests/SDLMetalVisibleTests/SDLMetalVisibleTests.m`: UI test captures the Simulator screen and asserts a bright center pixel for the triangle.
- Local YAML, shell, plist, source membership, and `git diff --check` validate. SDL/API and Metal rendering are not yet validated after these visible/UI changes; no physical-device claim.

## Last interrupted/unfinished operation

- No shell command was active at recovery. The latest completed operation is the local validation suite: YAML, Bash, plist, target/scheme/source exclusion, XCTest count, host HPL2 math harnesses, frame-clock harness, resource ASan/UBSan harness, and `git diff --check`. None of the new visible-triangle/UI-test changes have yet been pushed.

## Immediate next steps

1. Commit/push the current visible SDL Metal triangle and screenshot UI-test changes to `origin/main` after reviewing the exact diff.
2. Inspect the new Actions run through completion; verify the screenshot assertion, device/Simulator app builds, and UI `.xcresult` upload.
3. If any step fails, inspect the first actual failure and repair it without suppressing assertions; then rerun.
4. Update `PORT_PROGRESS.md`, `PORT_TASKS.md`, and this checkpoint with the verified run ID/result; do not claim physical iPhone output.
5. Continue with a small, compilable HPL2 `iLowLevelGraphics` Metal integration investigation.

## Remaining boundary

- The current C++/Metal math and Metal triangle tests are standalone probes.
- The visible UI test and SDL Metal triangle are not yet verified on Simulator or device.
- No HPL2 Metal backend, HPL2 scene, Amnesia level, or playable game has been built or rendered.
