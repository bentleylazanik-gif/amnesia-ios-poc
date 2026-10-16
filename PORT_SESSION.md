# Port Session Checkpoint

Updated: 2026-10-16

## Repository

- Repo: `bentleylazanik-gif/amnesia-ios-poc`; worktree: `/tmp/tmp.VZQPoiHQ4P`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Last committed checkpoint before adapter implementation: local `HEAD` and `origin/main` both `ef9b27937a41b8a30802afce6118a733c64fa8e6`; the remote was verified before editing.
- No command is interrupted or running. Current worktree contains the new uncommitted adapter implementation, XCTest fixture, and XcodeGen wiring under `ios-sdl-poc/`; preserve them. The HPL2 source worktree remains on pinned `acc95cd...` and its pre-existing untracked staged project files are untouched.
- Current milestone: HPL2 vertex/index descriptor adapter implementation; local GCC strict-warning + ASan/UBSan host smoke passed for both size-bearing views and extraction from an `iVertexBuffer` test double. YAML, Bash, target membership/exclusion, and `git diff --check` passed. Xcode/XcodeGen are unavailable in this Linux environment, so Simulator/device SDK verification is pending Actions.

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

1. Review and commit the adapter changes; push only after confirming the remote is still at `ef9b27937a41b8a30802afce6118a733c64fa8e6`. The code paths trigger iOS workflow CI.
2. Inspect that run to completion: adapter static library/device-SDK compilation, expanded Simulator XCTest suite, probe exclusion, app device/Simulator builds, IPA packaging, visible triangle test, and `.xcresult` uploads.
3. Fix any real failure without weakening assertions. If green, continue with a separate Metal uploader that consumes the validated descriptors. The upstream `iVertexBuffer` byte-length limitation remains documented; this adapter is not yet a renderer.
4. Keep device SDK builds, Simulator rendering, physical iPhone, and genuine HPL2 scene evidence distinct in all reporting.
