# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Latest pushed checkpoint: `c9604155a8a2bd1645f315ef2f1a324c021a167d` on `main`; local HEAD and origin/main matched after push.
- Adapter run `38861903111` succeeded: device-SDK adapter compile, 14 core/adapter Simulator tests, app SDK builds/IPA and visible UI test all passed.
- Uploader run `38862662245` succeeded on `e739f6c`: 15 core/adapter/uploader Simulator tests, Metal buffer byte/descriptor assertions, device-SDK and app builds/IPA and visible UI test passed. Link: https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38862662245.
- Matrix run `38863325630` completed successfully on `46ebd5f`: 18 core/adapter/matrix Simulator tests (including 3 matrix tests), device-SDK compilation, app SDK builds/IPA, and visible UI test all passed.
- Draw run `38864375503` succeeded against `15cc206`: 19 core/adapter/matrix Simulator tests (including MSL indexed-quad draw/readback) and the visible SDL triangle UI test passed; device-SDK compilation, app SDK builds, IPA and result artifacts passed. Link: https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38864375503.
- Stateful draw run `38867225798` succeeded against `93e2461`: 25 core/adapter/matrix/state Simulator tests, device-SDK compile, app builds/IPA and visible UI test passed.
- Alpha/diffuse separation run `38867486652` succeeded against `c960415`: 25 core/adapter/matrix/state Simulator tests (0 failures), including `testSyntheticHPL2VertexBufferFixtureUploadsAndDrawsIndexedQuad` with an independent transparent alpha map; app device/Simulator builds/IPA and visible UI test also passed. Its source predates the current uncommitted native surface integration.
- Current uncommitted app milestone: replace SDL_Renderer with `SDL_WINDOW_METAL` + `SDL_Metal_CreateView`, acquire/present one SDL-provided drawable, and display a synthetic HPL2-format indexed quad using the adapter/uploader/matrix/state/draw path. This is not a shipped/game mesh. The earlier SDL_Renderer screenshot run does not verify this native surface change. Main/XcodeGen/README/checkpoint files are modified and need static checks plus a new Actions run. The HPL2 source worktree remains pinned `acc95cd...`; its pre-existing untracked files remain untouched.

## Latest verification

- UI-visible Metal triangle workflow: run `38849387990`, success: https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38849387990 (workflow head `60702b029728accdb065c0636e762291fa5423ec`; subsequent `164959a` is documentation-only and is outside workflow path filters).
  - XcodeGen/project generation passed.
  - 8 core XCTest methods passed, including CRC, quaternion/matrix, frame clock, resource behavior, and offscreen Metal rendering/readback/bounds/repeat checks.
  - `testSDLAppPresentsMetalTriangleToDisplay` passed on an iOS Simulator: launched `org.example.sdltouchpoc`, captured the `SDL Metal triangle screen` attachment, and passed the bright-center-pixel assertion (1 UI test, 0 failures).
  - Device-SDK compilation, unsigned SDL app device and Simulator SDK builds, IPA packaging, and app artifacts passed.
  - Both `HPL2CRCSmoke.xcresult` and `SDLMetalVisible.xcresult` uploaded. The latest visible result artifact is available at https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38849387990/artifacts/12024444203.
  - This is Simulator visible-rendering evidence only, not physical-iPhone evidence, and not an HPL2 renderer.
- Earlier source-exclusion run `38779197725` passed; build logs confirmed the Metal probe object is compiled under its separate probe target and not the `SDLTouchPoC` app target.
- Earlier detailed probe/core run `38806244632` passed eight Simulator tests, including offscreen Metal triangle pixel readback and invalid/oversized dimensions/repeated-render checks.

## Current implementation boundary

- `ios-sdl-poc/Sources/main.c` selects SDL3's Metal renderer and draws an original triangle via `SDL_RenderGeometry`; SDL owns its drawable. Simulator screenshot pixel assertion passed.
- No physical iPhone 11 Pro build/install/visual evidence is available. The iOS device-SDK build is compile/package evidence only.
- Pinned HPL2 revision: `acc95cdedd6c94db89dc924eb9afa23185df562f`. `LowLevelGraphics.h` exposes 97 pure virtual methods; `Engine.cpp::CreateHPLEngine` selects only `eHplAPI_OpenGL`/`cSDLEngineSetup`; Amnesia `LuxBase.cpp::InitEngine` requests OpenGL; `Graphics.cpp` eagerly creates deferred, wireframe, and simple renderers, which load GLSL shader files. `cMeshCreator::CreatePlane` calls `CreateVertexBuffer`, defines position/normal/color/UV streams, adds four vertices and six indices, compiles tangents, then attaches the buffer to a `cSubMesh` with a material. This is a candidate for a testable HPL2-to-backend submission seam, but the path depends on wide graphics/resource interfaces. The source checkout has no game asset/shader corpus.
- No HPL2 Metal backend, genuine Amnesia mesh/material/scene, or playable game has been built or rendered.

## Next action

1. The stateful draw and alpha/diffuse runs `38867225798`/`38867486652` both completed successfully; preserve those run IDs as regression evidence.
2. Finish reviewing the native SDL_Metal_CreateView presenter/lifecycle and app static-library dependencies; rerun YAML/Bash/exclusion checks (Xcode unavailable locally).
3. Commit/push this app integration only after confirming `origin/main` still equals `c9604155a8a2bd1645f315ef2f1a324c021a167d`; inspect the new Actions build, actual screenshot UI test, and `.xcresult`.
4. On success, move from the app fixture toward real HPL2 asset loading and material translation; maintain a hard distinction between fixture draw, real mesh, and Amnesia scene.
5. Keep device-SDK builds, Simulator render tests, physical-iPhone evidence, and genuine Amnesia-scene evidence separate.
