# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Latest pushed checkpoint: `213c7adb50035f7f97d01f677e67e622fb937b16` on `main`; `38901341636` ran against it and exposed two app compile errors, now fixed in the local presenter source.
- Runs `38861903111` (descriptor adapter), `38862662245` (Metal buffer uploader), `38863325630` (matrix), `38864375503` (initial indexed draw), `38867225798` (render state), `38867486652` (alpha/diffuse separation), and `38870203930` (native SDL Metal surface) all passed. See PORT_PROGRESS.md for per-run test/build counts.
- Latest completed run `38870203930` verified `SDL_Metal_CreateView` app path: 25 core Simulator tests, device-SDK compile, unsigned app device/Simulator builds and IPA, plus visible screenshot test `testSDLAppPresentsMetalGeometryToDisplay` (1/0 failures; `SDL Metal indexed quad screen` attachment). This is synthetic geometry, not an Amnesia asset or physical iPhone run.
- MSH reader run `38898274435` succeeded on `d0ac24e`: device-SDK parser compile and 4 MSH XCTest methods passed within 29 total Simulator tests (0 failures), app builds/IPA and native-surface UI passed. It supports static one-submesh MSH v7 only and does not prove compatibility with an actual shipped asset. HPL2 source checkout remains pinned at `acc95cd...`; its untracked stage is untouched.
- App import path in `213c7ad` loads optional owner-provided `Documents/HPL2Import/preview.msh`, fits/draws a static MSH v7 submesh, and falls back to the explicitly synthetic fixture only if absent. `38901341636` passed 30/30 Simulator tests including EngineResource file read, but app device-SDK compile failed: unary negation is not defined for `cVector3f`, and `SDL_Log` was unavailable. Both errors were fixed locally with component-wise negation and `fprintf`; the app regression must rerun. User file is not packaged; only unlit vertex-color/white-texture preview, no Amnesia material/scene.

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

1. Verify the local compile corrections and inspect the complete `HPL2MetalWindowPresenter.mm` diff for lifetime/error handling; retain the successful 30-test evidence from failed run `38901341636` separately from its failed app-build result.
2. Parser hardening is in progress: reject truncated stream payload lengths before allocating; XCTest adds a 500-million-vertex malformed declaration. A new end-to-end MSH fixture test exercises parser→Metal upload→indexed draw→center-pixel readback. Host ASan/UBSan parser smoke passes; Metal XCTest is pending.
3. Let Actions run `38901969951` validate commit `a9255ab` app/device/Simulator/IPA/UI path before pushing the new parser/Metal test. It was queued at checkpoint. Then stage the parser hardening and end-to-end assertion, rerun static checks/host smoke, and trigger CI.
4. No Xcode is installed locally, so only Actions can validate Obj-C++/Metal/app. Consider a test-only visual injection path only if it can stay outside shipping app code; never label generated fixture as Amnesia content.
5. Keep device-SDK builds, Simulator render tests, physical-iPhone evidence, and genuine Amnesia-scene evidence separate.
