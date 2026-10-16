# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Last committed source checkpoint: `e739f6cf669bc0cd172aa6ccb2baed1e36a03274` on `main`; local HEAD and origin/main matched after push. It includes the descriptor adapter, Metal uploader, and Simulator test definitions.
- Adapter Actions run `38861903111` completed successfully: https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38861903111. The new adapter static library compiled for device SDK; the Simulator suite ran 14 tests (8 foundation + 6 adapter), 0 failures; app device/Simulator builds, IPA, visible triangle UI test, and artifacts passed.
- Uploader CI run `38862662245` tests the uploader source checkpoint. It was started with a background `gh run watch`; inspect its final logs when notified.
- Current uncommitted milestone: `HPL2MetalMatrixAdapter.{h,cpp}` converts HPL2 `m[row][column]` storage to Metal column-major and remaps OpenGL projection depth [-w,+w] to Metal [0,+w], with XCTest and XcodeGen wiring. Host GCC strict-warning + ASan/UBSan smoke passed for matrix transform and depth endpoints. This is CPU transform conversion only; Simulator CI remains pending. Preserve these changes. The HPL2 source worktree remains pinned `acc95cd...`; its pre-existing untracked staged files are untouched.
- YAML/Bash/XcodeGen target wiring and app-source exclusions pass locally. Xcode/XcodeGen are unavailable in Linux, so matrix/uploader Obj-C++ Simulator tests and iOS SDK builds require Actions.

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

1. Inspect run `38862662245` for the Metal uploader source through completion; diagnose any first failure without weakening tests.
2. Run final local YAML/Bash/host ASan checks for the matrix adapter; verify it is excluded from the SDL app and wired only into the core test scheme.
3. Commit/push the matrix adapter only after confirming `origin/main` remains `e739f6cf669bc0cd172aa6ccb2baed1e36a03274`; inspect its Actions run through completion.
4. If green, continue to a simple-pass Metal encoder/pipeline and HPL2 draw submission; preserve the `iVertexBuffer` byte-length limitation. Buffers/matrices alone are not an HPL2 renderer.
5. Keep device-SDK builds, Simulator rendering, physical-iPhone evidence, and genuine Amnesia-scene evidence separate.
