# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Recovery verified: local `HEAD`, `origin/main`, and `git ls-remote origin refs/heads/main` all match `b696ddf66dd4a2eaf761185659e5a282612d392b`; worktree was clean at recovery.
- No command is interrupted or running. Current task: implement a tested view/descriptor adapter for actual HPL2 vertex/index buffers, beginning with the pinned `iVertexBuffer` API and the `CreatePlane` → `RendererSimple` call path. Preserve later source edits; do not reset/clean.

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

1. Commit this evidence update after reviewing `git diff --check`; push only if `main` still matches `origin/main`.
2. The `cMeshCreator::CreatePlane` → `cRendererSimple::RenderObjects` path is now mapped: HPL2 builds position/normal/color/UV/index arrays; renderer sets depth/blend/alpha/channel, binds program/texture/matrix/buffer, then calls `iVertexBuffer::Draw`. Implement the next small step as a tested adapter from actual HPL2 vertex arrays to Metal vertex/index upload layout (stride, optional attributes, index bounds), without claiming it is an HPL2 renderer.
3. Make this adapter compile against the pinned HPL2 headers and add host/CI tests; then exercise it with `CreatePlane`-generated data before proceeding to Metal encoder/pipeline and simple-pass state mapping.
4. Keep device SDK builds, Simulator rendering, physical iPhone, and genuine HPL2 scene evidence distinct in all reporting.
