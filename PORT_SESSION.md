# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Latest pushed checkpoint: `15cc2069924b9e12d3f97b8c1e7a524d0a66a21e` on `main`; local HEAD and origin/main matched after push.
- Adapter run `38861903111` succeeded: device-SDK adapter compile, 14 core/adapter Simulator tests, app SDK builds/IPA and visible UI test all passed.
- Uploader run `38862662245` succeeded on `e739f6c`: 15 core/adapter/uploader Simulator tests, Metal buffer byte/descriptor assertions, device-SDK and app builds/IPA and visible UI test passed. Link: https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38862662245.
- Matrix run `38863325630` completed successfully on `46ebd5f`: 18 core/adapter/matrix Simulator tests (including 3 matrix tests), device-SDK compilation, app SDK builds/IPA, and visible UI test all passed.
- Draw run `38864375503` succeeded against `15cc206`: 19 core/adapter/matrix Simulator tests (including MSL indexed-quad draw/readback) and the visible SDL triangle UI test passed; device-SDK compilation, app SDK builds, IPA and result artifacts passed. Link: https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38864375503.
- Current uncommitted work adds `HPL2MetalRenderStateAdapter.{h,mm}` + XCTest for HPL2 depth/cull/channel/blend/alpha/filter/wrap mapping and wires those states into the MSL draw pipeline/encoder (color mask/blend, depth, culling, alpha discard). The updated test runs synthetic HPL2-shaped data through a Z pass and equal-depth color pass, including opaque and transparent-alpha fixtures. It is not an Amnesia asset, scene, or complete engine backend. YAML/Bash/target checks and GCC ASan/UBSan adapter/matrix smokes pass; Obj-C++/Metal state/draw tests await CI. The HPL2 source worktree remains pinned `acc95cd...`; pre-existing untracked files untouched.

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

1. Recheck run `38864375503` logs for the passed synthetic MSL indexed draw/readback; it is successful, not a real Amnesia render.
2. Review local render-state adapter and Z/diffuse pass integration, then run YAML/Bash/target-exclusion and host ASan checks.
3. Commit/push only after confirming `origin/main` remains at `15cc2069924b9e12d3f97b8c1e7a524d0a66a21e`; inspect the new stateful draw/test Actions run through completion.
4. If green, continue with SDL_Metal_CreateView ownership/lifecycle and real HPL2 renderer seam; current synthetic fixture does not render game assets. Still no Amnesia asset or scene has rendered.
5. Keep device-SDK builds, Simulator render tests, physical-iPhone evidence, and genuine Amnesia-scene evidence separate.
