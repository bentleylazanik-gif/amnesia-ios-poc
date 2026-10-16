# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Latest pushed checkpoint: `f6d4631d0bb5443084811ef17bdb4c925677b5ff` on `main`; local HEAD and origin/main match. Runs `38901969951` (`a9255ab`) and `38902737527` (`b278322`) both completed successfully; new follow-up run `38904408846` is in progress.
- Runs `38861903111` (descriptor adapter), `38862662245` (Metal buffer uploader), `38863325630` (matrix), `38864375503` (initial indexed draw), `38867225798` (render state), `38867486652` (alpha/diffuse separation), and `38870203930` (native SDL Metal surface) all passed. See PORT_PROGRESS.md for per-run test/build counts.
- Latest completed run `38870203930` verified `SDL_Metal_CreateView` app path: 25 core Simulator tests, device-SDK compile, unsigned app device/Simulator builds and IPA, plus visible screenshot test `testSDLAppPresentsMetalGeometryToDisplay` (1/0 failures; `SDL Metal indexed quad screen` attachment). This is synthetic geometry, not an Amnesia asset or physical iPhone run.
- MSH reader run `38898274435` succeeded on `d0ac24e`: device-SDK parser compile and 4 MSH XCTest methods passed within 29 total Simulator tests (0 failures), app builds/IPA and native-surface UI passed. It supports static one-submesh MSH v7 only and does not prove compatibility with an actual shipped asset. HPL2 source checkout remains pinned at `acc95cd...`; its untracked stage is untouched.
- App import path in `213c7ad` loads optional owner-provided `Documents/HPL2Import/preview.msh`, auto-fits/draws the static MSH v7 subset, and uses the explicitly synthetic fallback only if absent. Compile fixes in `a9255ab` passed run `38901969951`: 30 Simulator tests (0 failures), device SDK compile, unsigned device/Simulator app builds, IPA, and visible indexed-quad screenshot UI test (1/0 failures). Run `38902737527` on `b278322` passed 31 Simulator tests (0 failures), including `testGeneratedMSHFixtureUploadsAndDrawsIndexedMeshInMetal`, and repeated device SDK/app device/Simulator/IPA/UI checks. User-provided content remains untested; preview uses unlit vertex colors and white texture, not Amnesia materials/scenes. Artifacts for run `38902737527`: IPA `12047315923`; visible `.xcresult` `12047332080`; app products `12046048630`; math `.xcresult` `12047127583`.

## Latest verification

- Latest integrated run `38902737527` on `b278322`: 31 Simulator XCTest methods passed, 0 failures; device-SDK Metal/math targets compiled; unsigned app device and Simulator builds; IPA package; visible UI screenshot test passed (1 test, 0 failures). `testGeneratedMSHFixtureUploadsAndDrawsIndexedMeshInMetal` parsed synthetic MSH v7 bytes and verified offscreen indexed Metal pixel output. Artifacts: IPA `12047315923`, `SDLMetalVisible.xcresult` `12047332080`, app products `12046048630`, `HPL2CRCSmoke.xcresult` `12047127583`.
- The UI test `testSDLAppPresentsMetalGeometryToDisplay` launched via `SDL_Metal_CreateView`, saved `SDL Metal indexed quad screen`, and passed its bright-center-pixel assertion. The imported file was not present in the Simulator; this screenshot verifies only synthetic fallback geometry, not a game asset, HPL2 full renderer, physical iPhone, or Amnesia scene.
- Earlier source-exclusion run `38779197725` passed; build logs confirmed the Metal probe object is compiled under its separate probe target and not the `SDLTouchPoC` app target.
- Earlier detailed probe/core run `38806244632` passed eight Simulator tests, including offscreen Metal triangle pixel readback and invalid/oversized dimensions/repeated-render checks.

## Current implementation boundary

- `main.c` now creates an `SDL_WINDOW_METAL` window; `HPL2MetalWindowPresenter.mm` acquires/presents the SDL Metal drawable and renders the synthetic HPL2 vertex fixture through MTLBuffer upload, unlit MSL, HPL2 matrix/state conversions, and indexed draw. Run `38870203930` screenshot UI test passes on Simulator.
- No physical iPhone 11 Pro install/visual evidence. Device SDK result is compile/package evidence only.
- Pinned HPL2 revision: `acc95cdedd6c94db89dc924eb9afa23185df562f`. `LowLevelGraphics.h` exposes 97 pure virtual methods; `Engine.cpp::CreateHPLEngine` selects only `eHplAPI_OpenGL`/`cSDLEngineSetup`; Amnesia `LuxBase.cpp::InitEngine` requests OpenGL; `Graphics.cpp` eagerly creates deferred, wireframe, and simple renderers, which load GLSL shader files. `cMeshCreator::CreatePlane` calls `CreateVertexBuffer`, defines position/normal/color/UV streams, adds four vertices and six indices, compiles tangents, then attaches the buffer to a `cSubMesh` with a material. This is a candidate for a testable HPL2-to-backend submission seam, but the path depends on wide graphics/resource interfaces. The source checkout has no game asset/shader corpus.
- No HPL2 Metal backend, genuine Amnesia mesh/material/scene, or playable game has been built or rendered.

## Next action

1. Inspect Actions run `38904408846` for commit `f6d4631`; its MSH error/alignment tests must pass within XCTest, followed by app device/Simulator build, IPA, and visible UI regression.
2. If it passes, reconcile the exact test count/artifacts in all three checkpoint files. If it fails, inspect the first concrete compiler/test error and fix the root cause before rerunning.
3. Continue toward actual owner mesh compatibility: extend the static reader beyond one submesh or implement a minimal supported material/texture mapping, based on source/corpus feasibility. Owner assets remain absent, so do not call generated fixture an Amnesia mesh.
4. No Xcode is installed locally, so only Actions can validate Obj-C++/Metal/app. Consider a test-only visual injection path only if it can stay outside shipping app code; never label generated fixture as Amnesia content.
5. Keep device-SDK builds, Simulator render tests, physical-iPhone evidence, and genuine Amnesia-scene evidence separate.
