# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Last committed source checkpoint: `14975e2d4f6f7744560117dbdb7e5ea844cb1a18` on `main`; local HEAD and origin/main matched when verified. It adds the HPL2 descriptor adapter and its tests.
- Adapter Actions run `38861903111` was queued at checkpoint time: https://github.com/bentleylazanik-gif/amnesia-ios-poc/actions/runs/38861903111. A background `gh run watch` was started through the shell tool; resume/inspect the run, do not assume it finished.
- Current local milestone adds `HPL2MetalMeshUploader.{h,mm}`, a Metal buffer uploader and Simulator XCTest for actual buffer bytes/descriptor metadata; XcodeGen wires a separate target, excluded from the SDL app. These uploader changes and updated progress/task/session docs are uncommitted. The HPL2 source worktree remains on pinned `acc95cd...` and its pre-existing untracked staged project files are untouched.
- Local GCC strict-warning + ASan/UBSan host smokes passed for size-bearing views and extraction from an `iVertexBuffer` test double. YAML, Bash, target membership/exclusions, and `git diff --check` passed. Xcode/XcodeGen are unavailable locally, so Obj-C++ compilation, Metal buffer XCTest, iOS SDK builds, and full Simulator UI run require Actions.

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

1. Inspect adapter run `38861903111` through completion and fix real errors. Meanwhile finish local review of the Metal uploader changes.
2. Commit/push uploader changes only after confirming `origin/main` is still at `14975e2d4f6f7744560117dbdb7e5ea844cb1a18`; this will start a workflow for the uploader code.
3. Verify actual MTLBuffer content/descriptor XCTest, adapter/core regression tests, device-SDK compile, app Simulator/device builds, IPA, visible-triangle UI test, and `.xcresult` uploads.
4. If green, continue to encoder/pipeline and HPL2 draw submission; retain the documented `iVertexBuffer` byte-length limitation. Neither adapter nor upload is yet an HPL2 renderer.
4. Keep device SDK builds, Simulator rendering, physical iPhone, and genuine HPL2 scene evidence distinct in all reporting.
