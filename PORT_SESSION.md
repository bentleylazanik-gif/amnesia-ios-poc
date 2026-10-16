# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Latest pushed checkpoint at recovery: `709b64ab12e5f30896d7a19081418d88fd801488` on `main`; local HEAD, origin/main, and ls-remote matched; worktree was clean before starting the MSH-reader milestone.
- Prior runs `38861903111` (adapter), `38862662245` (Metal uploader), `38863325630` (matrix), `38864375503` (initial indexed draw), `38867225798` (state mapping), and `38867486652` (separate alpha/diffuse textures) all completed successfully. Each is documented in PORT_PROGRESS.md; none renders a real game asset.
- Latest run `38870203930` succeeded on source `709b64a`: adapter/uploader/state/matrix targets compiled for iOS device SDK; 25 core Simulator tests passed; unsigned app device and Simulator SDK builds and IPA packaging passed; `HPL2MetalWindowPresenter.mm` compiled for device and both Simulator architectures; `testSDLAppPresentsMetalGeometryToDisplay` passed on Simulator (1 UI test, 0 failures) with attachment `SDL Metal indexed quad screen`. App and both `.xcresult` artifacts uploaded. This verifies the native SDL_Metal_CreateView surface and synthetic indexed fixture only—not physical iPhone or Amnesia content.
- Current uncommitted milestone: a limited pinned MSH v7 static one-submesh reader and focused XCTest fixture, plus XcodeGen target wiring/docs. Host ASan/UBSan parser→adapter smoke passes. It deliberately rejects skeletons, node hierarchies, skinning, animations, and multiple submeshes; it has not run on Apple CI. Preserve these changes. HPL2 source worktree stays pinned `acc95cd...` and its pre-existing untracked staged files remain untouched.

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

1. Review the local `HPL2MetalMSHReader` parser against pinned `MeshLoaderMSH::LoadMesh/SaveMesh` serialization and run its host ASan/UBSan fixture smoke (already passing once; rerun after edits).
2. Validate that parser/XCTest target uniqueness, sparse header dependencies, and SDL app exclusions are correct; no Xcode is available locally.
3. Commit/push this reader milestone only after confirming `origin/main` remains at `709b64ab12e5f30896d7a19081418d88fd801488`; inspect the CI parser tests and app regression results.
4. After it passes, connect a documented app-container path for user-supplied `.msh` files, retaining the static fixture as an explicit fallback; do not package or fabricate game assets.
5. Keep device-SDK builds, Simulator render tests, physical-iPhone evidence, and genuine Amnesia-scene evidence separate.
