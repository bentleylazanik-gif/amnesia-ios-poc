# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Latest pushed checkpoint: `d0ac24ebc3f26f3c0068956b919fc0958c6264b3` on `main`; local HEAD, origin/main and ls-remote matched before the current presenter asset-loading edits.
- Runs `38861903111` (descriptor adapter), `38862662245` (Metal buffer uploader), `38863325630` (matrix), `38864375503` (initial indexed draw), `38867225798` (render state), `38867486652` (alpha/diffuse separation), and `38870203930` (native SDL Metal surface) all passed. See PORT_PROGRESS.md for per-run test/build counts.
- Latest completed run `38870203930` verified `SDL_Metal_CreateView` app path: 25 core Simulator tests, device-SDK compile, unsigned app device/Simulator builds and IPA, plus visible screenshot test `testSDLAppPresentsMetalGeometryToDisplay` (1/0 failures; `SDL Metal indexed quad screen` attachment). This is synthetic geometry, not an Amnesia asset or physical iPhone run.
- MSH reader run `38898274435` succeeded on `d0ac24e`: device-SDK parser compile and 4 MSH XCTest methods passed within 29 total Simulator tests (0 failures), app builds/IPA and native-surface UI passed. It supports static one-submesh MSH v7 only and does not prove compatibility with an actual shipped asset. HPL2 source checkout remains pinned at `acc95cd...`; its untracked stage is untouched.
- Current uncommitted app improvement optionally imports a user-owned MSH v7 file from `Documents/HPL2Import/preview.msh`, auto-fits it, and uses the fixture only if the file is absent. The user file is not packaged. It preserves the material name but previews with white texture/unlit vertex color; app/asset path validation is pending CI.

## Latest verification

- Latest app/native surface run `38870203930`: success on source `709b64ab12e5f30896d7a19081418d88fd801488`. Device-SDK compile, Simulator XCTest (25 tests, 0 failures), device/Simulator app builds, IPA, and UI test all passed.
- The UI test `testSDLAppPresentsMetalGeometryToDisplay` launched the app using the new `SDL_Metal_CreateView` path, saved `SDL Metal indexed quad screen`, and passed a bright-center-pixel assertion (1 UI test, 0 failures). `HPL2MetalWindowPresenter.mm` compiled for iOS device SDK, Simulator arm64, and Simulator x86_64. Artifacts include `HPL2CRCSmoke.xcresult` and `SDLMetalVisible.xcresult` (ID `12032944877`).
- This verifies visible synthetic HPL2-format fixture geometry on Simulator only. It is not a game asset, HPL2 full renderer, physical iPhone run, or Amnesia scene.
- Earlier source-exclusion run `38779197725` passed; build logs confirmed the Metal probe object is compiled under its separate probe target and not the `SDLTouchPoC` app target.
- Earlier detailed probe/core run `38806244632` passed eight Simulator tests, including offscreen Metal triangle pixel readback and invalid/oversized dimensions/repeated-render checks.

## Current implementation boundary

- `main.c` now creates an `SDL_WINDOW_METAL` window; `HPL2MetalWindowPresenter.mm` acquires/presents the SDL Metal drawable and renders the synthetic HPL2 vertex fixture through MTLBuffer upload, unlit MSL, HPL2 matrix/state conversions, and indexed draw. Run `38870203930` screenshot UI test passes on Simulator.
- No physical iPhone 11 Pro install/visual evidence. Device SDK result is compile/package evidence only.
- Pinned HPL2 revision: `acc95cdedd6c94db89dc924eb9afa23185df562f`. `LowLevelGraphics.h` exposes 97 pure virtual methods; `Engine.cpp::CreateHPLEngine` selects only `eHplAPI_OpenGL`/`cSDLEngineSetup`; Amnesia `LuxBase.cpp::InitEngine` requests OpenGL; `Graphics.cpp` eagerly creates deferred, wireframe, and simple renderers, which load GLSL shader files. `cMeshCreator::CreatePlane` calls `CreateVertexBuffer`, defines position/normal/color/UV streams, adds four vertices and six indices, compiles tangents, then attaches the buffer to a `cSubMesh` with a material. This is a candidate for a testable HPL2-to-backend submission seam, but the path depends on wide graphics/resource interfaces. The source checkout has no game asset/shader corpus.
- No HPL2 Metal backend, genuine Amnesia mesh/material/scene, or playable game has been built or rendered.

## Next action

1. The MSH parser milestone is verified by run `38898274435`; retain its 4 focused parser cases and host ASan/UBSan smoke results.
2. Implement optional loading of owner-supplied `Documents/HPL2Import/preview.msh` through `EngineResourceAccess` + the static MSH reader, preserving the existing fixture only as a missing-file fallback. Keep material/texture and unsupported file features explicit.
3. Add a parser/presenter XCTest for user-file load if practical, run local target/safety checks, and commit only after inspecting the diff.
4. Push only if `origin/main` is still at `d0ac24ebc3f26f3c0068956b919fc0958c6264b3`; inspect the next full Actions run through completion. Never imply the generated fixture is an Amnesia asset.
5. Keep device-SDK builds, Simulator render tests, physical-iPhone evidence, and genuine Amnesia-scene evidence separate.
