# Amnesia iOS Port Progress

Last updated: 2026-10-15

## Verified repository baseline

- Repository: `bentleylazanik-gif/amnesia-ios-poc`; branch: `main`; remote: `https://github.com/bentleylazanik-gif/amnesia-ios-poc.git`.
- Before the latest work, GitHub `main` was `6f587c6` (`Add HPL2 quaternion smoke test`). That commit contains the SDL3 PoC and CRC/Quaternion test targets.
- The last known passing Actions run before Quaternion was run `38686449022` on `548027b`: CRC compiled for the iOS device SDK and its XCTest passed on an iOS Simulator. It was not a physical-device HPL2 test.
- Actions run `38741245297` on `6f587c6` failed in the upstream sparse-source staging step before Xcode ran. Exact error: `Pinned upstream file is missing: HPL2/core/include/graphics/Color.h`.
- The owner reports that the separate SDL3 3.4.18 app was built, signed, installed, and run on an iPhone 11 Pro; tapping changes its blue screen to red. Its app source is preserved.
- Upstream Amnesia is pinned at `acc95cdedd6c94db89dc924eb9afa23185df562f`. No commercial game assets are included.

## Current milestone: HPL2 quaternion transforms

Keep CRC and add the real `Quaternion.cpp` rotation implementation as a math step toward camera/object transforms. The test covers a 90-degree Z rotation, two-turn composition, and quaternion/matrix round-tripping. This is not HPL2 boot, renderer integration, scene loading, or an Amnesia game run.

## Changes made in this session

- Fixed the sparse-checkout pattern bug: the old Bash prefix substitution produced backslash-prefixed paths, leaving the requested upstream files absent. The workflow now passes repository-relative paths directly and stages only the selected HPL2 math source/header closure.
- Added `HPL2Quaternion` as a separate static library; added quaternion assertions alongside the existing CRC XCTest.
- Updated README and this progress log. At the quaternion-only point, SDL3 app source and build steps remained unchanged; later host-foundation work is recorded below.
- Commit `2134862` contains the sparse-checkout correction and quaternion milestone notes. It was local/unpushed when this section was first written, then was included in the subsequently pushed `main` history.

## Dependency and test evidence

- `Quaternion.cpp` includes `Math.h` and `LowLevelSystem.h`; a compiler dependency scan found 16 HPL2 headers across math, graphics-type, and system declarations. The implementation has no platform API or external library link references.
- The sparse source staging command was exercised in a temporary directory and checked out exactly 18 upstream files at the pinned SHA (CRC + Quaternion and the header closure), with no desktop dependencies or assets.
- Linux host C++ compilation/execution of the pinned CRC and Quaternion sources passed: CRC `0x89A1897F`, Z-axis rotation, two-turn composition, and matrix round-trip. An initial harness used aliases not declared by `Quaternion.h` alone; correcting it to `cVector3<float>` and `cMatrix<float>` made the test pass. This is host-only evidence, not an iOS build.
- Workflow and project YAML, host plist, Bash syntax, README shell syntax, and `git diff --check` passed. The two existing SDL device/Simulator build command bodies are unchanged.
- The AQ workspace is Linux and lacks `xcodebuild`, XcodeGen, and `xcrun`. At the time this section was first recorded, the new HPL2 device-SDK build and Simulator XCTest had not run; Actions run `38743949963` later passed both, as detailed below. Do not confuse that Simulator result with a physical-device test.

## Recovery and next action

- Worktree: `/tmp/tmp.VZQPoiHQ4P`. Preserve all current files; do not reset or clean.
- Keep `ios-sdl-poc/Sources/main.c`, CRC tests, and `SDLTouchPoC` project target unchanged. `EngineSource/` is ignored scratch; only pinned math files are staged during CI.
- The earlier recovery action was to push local commit `2134862`; this was completed, and run `38743949963` passed. Subsequent platform/resource progress and current blockers are recorded in the sections below.
- No HPL2 scene has been rendered on Simulator or iPhone. Renderer/platform/resource adaptation and legitimate private game data remain future work.

## Repository and CI update (supersedes earlier next-action notes)

- Reconciled the reported state: the reported `6f587c6` exists on GitHub `main`; the separate Linux upstream-source worktree is at the pinned upstream commit, not the iOS PoC repository. The actual PoC worktree is `/tmp/tmp.VZQPoiHQ4P`.
- Commits `2134862` and `65bdea1` were pushed; local `HEAD`, local `main`, and `origin/main` were all `65bdea1313b3401101168eeaeb906601b83594bf` at verification. The worktree was clean.
- Actions run `38743949963` on `65bdea1` completed successfully: sparse staging, XcodeGen, HPL2 CRC+Quaternion device-SDK compilation, Simulator XCTest, unsigned SDL iOS device and Simulator builds, IPA packaging/artifact upload, and the conditional release-artifact job all succeeded. XCTest was on an iPhone Simulator, not a physical iPhone. The old failure run `38741245297` is resolved by the sparse path-pattern fix.

## Upstream portability map — source inspected at the pinned commit

All source references below were inspected in the full upstream checkout at `acc95cdedd6c94db89dc924eb9afa23185df562f`. “Verified” means source structure/API inspection, not a functioning port.

| Subsystem | Existing upstream implementation | iOS gap / proposed smallest step | Proof / status |
| --- | --- | --- | --- |
| Game entry and shutdown | `amnesia/src/game/Main.cpp` calls `cLuxBase::Init`, `Run`, `Exit`; platform launchers are separate under `amnesia/src/launcher*`. | Add a UIKit/SDL3 app entry that owns one engine instance and calls orderly shutdown; desktop `main`/launcher assumptions must not leak into app lifecycle. | Entry path verified; HPL2/Game startup not started. |
| Engine platform bootstrap | `HPL2/core/sources/impl/SDLEngineSetup.cpp` constructs SDL system, graphics, input, resources, OpenAL sound, and Newton physics backends. It includes SDL2 headers and has desktop SDL setup behavior. | Replace/extend this assembly behind existing low-level interfaces with an SDL3/iOS setup; initialize subsystems transactionally and unwind failures. | Exact coupling verified; not started. |
| Application lifecycle/window | Current PoC `ios-sdl-poc/Sources/main.c` uses SDL3 callback APIs, renderer/window, background/foreground events. | Host foundation resolves bundle/writable roots, reports SDL errors/logs, tracks drawable pixel-size changes, and measures capped monotonic deltas. Lifecycle notifications use `SDL_AddEventWatch` per SDL's iOS event docs; the cross-thread watcher touches only atomics, and frame-clock reset stays on the app callback thread. | Earlier device-SDK/Simulator app builds passed in run `38745751165`; latest lifecycle watcher and size-change additions are uncompiled on iOS. Run `38746838245` failed in XCTest at the missing fixture before app build steps. No physical-device lifecycle run. |
| Input and touch | `LowLevelInputSDL.cpp`, `MouseSDL.cpp`, `KeyboardSDL.cpp`, `GamepadSDL.cpp` / `GamepadSDL2.cpp` use SDL poll/mouse/keyboard/gamepad APIs; engine gameplay input is in `HPL2/core/sources/input` and `amnesia/src/game`. | Translate SDL3 touch/pointer events into an engine-neutral touch interface; define gestures for game actions separately. Do not treat the PoC color-switch as game input. | SDL2 mouse-oriented source verified; touch/game controls not started. |
| Graphics renderer | `LowLevelGraphicsSDL.cpp`, `VertexBufferOpenGL.cpp`, `VertexBufferOGL_{Array,VBO}.cpp`, `FrameBufferGL.cpp`, `GLSLProgram.cpp`, `OcclusionQueryOGL.cpp`, and `SDLTexture.cpp`. It includes macOS `OpenGL/OpenGL.h`, GLEW capability checks, EXT/ARB entry points, compatibility-profile state, and `glMatrixMode`, `glAlphaFunc`, client arrays, `glBegin/glEnd`, `GL_QUADS`, fixed-function texture env, and immediate-mode debug drawing. | Not a link-flag fix: isolate platform-neutral render interfaces; first build a standalone Metal view/device and clear it, then triangle and textured mesh. Current SDL renderer is independent and does not adapt HPL2 rendering. | Desktop coupling verified; iOS renderer not started. |
| Shaders/materials | HPL2 has `GLSLProgram`/shader abstractions and material/render code, but this checkout contains no shader/resource asset set (`find` found no GLSL/vertex/fragment files or game mesh/texture assets). | Audit the licensed/user-supplied shader/material set separately; translate supported shader programs to Metal and inventory required material features before claiming reuse. | Code abstraction verified; concrete shader corpus absent from this source checkout; blocked on asset corpus. |
| Resource access/loaders | `LowLevelResourcesSDL.cpp` registers Devil DDS/misc bitmap loaders, MSH and FBX mesh loaders, and Theora video. `LowLevelSystemSDL.cpp` obtains `cPlatform::GetDataDir()` and calls `chdir`; `PlatformUnix.cpp` uses UTF-8 `fopen` conversion. | PoC now separates SDL bundle and pref roots; `EngineResourceAccess` builds traversal-safe relative paths and reads files with explicit status codes. Next integrate through a platform interface and remove CWD dependence. Limit initial loaders to formats needed by an owned asset corpus. | SDL roots/frame clock passed CI. `bd6fc06` resource API compiled and its Unicode/space/empty/missing/traversal test passed, but overall run `38746838245` failed because the bundle fixture was not copied. XcodeGen resource-phase fix is local/unpushed. Not connected to HPL2's manager/cache. |
| Audio | `SDLEngineSetup.cpp` selects `cLowLevelSoundOpenAL`; implementation lives in `LowLevelSoundOpenAL.cpp` and `OpenAL*` sources, with OALWrapper/dependency linkage. | Verify an iOS-supported OpenAL implementation/availability for the pinned SDK; otherwise add an AVAudioEngine or SDL audio adapter behind HPL2 sound interfaces. | Backend selection verified; iOS sound build/playback unverified. |
| Physics | `SDLEngineSetup.cpp` selects `cLowLevelPhysicsNewton`; `LowLevelPhysicsNewton.cpp` and `*Newton.cpp` implement it. CMake expects prebuilt Newton. | Confirm license, source, ABI and arm64/iOS support; if unavailable choose an iOS-capable backend and adapt the HPL2 physics interface. | Desktop dependency reference verified; dependency binaries/source are absent from this checkout; blocked pending dependency decision. |
| Scripting/gameplay | CMake includes `SqScript.cpp`, `scriptarray.cpp`, `scripthelper.cpp`, `scriptstring.cpp`; Amnesia gameplay sources are under `amnesia/src/game`. | Trace exact script VM and game bootstrap dependencies; build a minimal script/game startup only after core/platform/resource interfaces exist. | Source references verified; runtime not started. |
| Threads/timers/synchronization | `ThreadSDL.cpp`, `MutexSDL.cpp`, `TimerSDL.cpp`, plus common system synchronization code. | Map SDL2-specific thread APIs to SDL3 and audit engine background jobs for iOS suspension/termination behavior. | Files verified; iOS build/runtime not started. |
| Configuration/logging | `LowLevelSystemSDL.cpp`, `PlatformUnix.cpp`, `PlatformMacOSX.mm`; current PoC now emits SDL structured logs and reports bundle/data paths. | Route HPL2 logs/config to app container, avoid CWD/home assumptions, and capture diagnostics on device. | PoC path/log foundation in progress; HPL2 layer not started. |
| Build/dependencies | `HPL2/core/CMakeLists.txt` unconditionally gathers GL/GLEW, Newton, AngelScript, FBX, Theora, Devil and OpenAL wrapper sources/libs; Apple branch is macOS-specific and links Cocoa/SystemConfiguration/OpenGL. `BoilerPlate.cmake` hard-codes macOS 10.6 and platform prefixes; `amnesia/src/CMakeLists.txt` selects the macOS launcher on Apple. | Create a dedicated iOS build target and audited dependency manifest; do not reuse desktop CMake Apple target unchanged. | Build constraints verified; no full iOS engine target. |
| Minimum real rendered scene | Renderer + scene/world + camera/frustum + mesh/material/texture + resource + input, with game scene parsers and supporting physics/audio/script paths to load actual Amnesia gameplay. | Sequence milestones: iOS graphics device/clear → triangle → texture/mesh → real resource loaded mesh → HPL2 scene; exclude unrelated backends only after tracing dependencies. | No engine scene has been rendered; not started. |

### Renderer-specific evidence

- `cLowLevelGraphicsSDL::Init` in `LowLevelGraphicsSDL.cpp` requests SDL `OPENGL`, color/depth/stencil buffers, creates an SDL GL context, and calls `glewInit()`; it does not request an iOS/ES profile. It initializes fixed-function matrices, alpha test, client arrays, and GL state.
- `VertexBufferOGL_Array.cpp` uses client-side vertex arrays; `VertexBufferOGL_VBO.cpp` uses ARB VBOs and unsigned-int index draws. `FrameBufferGL.cpp` uses EXT framebuffer/renderbuffer entry points. `SDLTexture.cpp` contains 1D/2D/3D and compressed texture paths, including formats/calls not available in a minimal iOS backend. `GLSLShader.cpp`/`GLSLProgram.cpp` compile/link GPU programs.
- No shader source files or game materials/textures/meshes are present in this pinned source checkout, so required GLSL versions/extensions and actually reusable materials cannot yet be established. Do not label existing desktop GLSL files “iOS compatible” without an asset/source corpus.
- The abstract `iLowLevelGraphics`/renderer interfaces are a possible seam, but most current capabilities are exposed as desktop GL state operations; implementing a backend means explicit feature mapping, not just linking Metal or renaming OpenGL. The first verifiable HPL2 graphics target should be a backend-owned Metal device/surface and render-target clear, then triangle. A triangle from the current SDL3 color-clear PoC is not an HPL2 renderer milestone.

## SDL host foundation (`a0bf41b`; CI verified)

- Added `Sources/EngineHostCore.[ch]`, a small C frame clock used by the SDL callback app. It computes monotonic nanosecond deltas, returns zero during suspension or non-monotonic timestamps, and clamps foreground stalls to 250 ms.
- Extended `main.c` to reset/pause the clock on lifecycle callbacks, use `SDL_GetBasePath()` for bundle resources and `SDL_GetPrefPath()` for writable data, log startup paths/drawable size and errors with SDL logging, and release the returned path buffers in shutdown. Existing touch colors and app target remain.
- Added deterministic XCTest coverage for a 16 ms frame, suspend/resume, clamping, and a backward timestamp. The XCTest target compiles the pure C helper. README now documents these boundaries.
- Local checks now pass: the C helper compiled with GCC C11 `-Wall -Wextra -Werror -pedantic` and a host harness exercised 16 ms, suspension/resume, 250 ms clamping, non-monotonic time, and null handling; project/workflow YAML, host plist, shell snippets, target wiring, and `git diff --check` also pass. These are host/syntax checks, not an iOS build.
- Commit `a0bf41b` was pushed to `main`; Actions run `38745751165` completed successfully. XcodeGen, HPL2 device-SDK compilation, all three then-existing XCTest methods on iOS Simulator, SDL app device/Simulator builds, IPA packaging, and artifact upload passed. The test log explicitly reports 3 tests, 0 failures; this was not a physical-device test.
- The Actions compiler log exposed a const-qualification warning: SDL 3.4.18 `SDL_GetBasePath()` returns SDL-owned `const char *`, while `SDL_GetPrefPath()` returns an owned buffer. The pending resource change corrects the base-path type and only frees the pref-path allocation. This is a CI-discovered correctness cleanup, not a failed build.
- A Simulator build does not demonstrate lifecycle behavior on an iPhone; the earlier owner-reported blue/red device PoC applies only to the earlier app state.

## Resource-access foundation (`bd6fc06`; CI failure being repaired)

- Added a standalone C API for safe relative path construction and whole-file reads rooted at a caller-selected directory. It rejects absolute paths, `.`/`..` traversal, repeated/trailing separators, and backslashes; returns explicit invalid/not-found/I/O/out-of-memory statuses; and handles zero-byte files without returning a null success buffer.
- Added XCTest coverage using a checked-in text fixture from the test bundle plus an app-writable temporary directory. Cases include distinct bundle and save roots (no implicit fallback), spaces, UTF-8 filename/content, empty file, missing file, path traversal, and absolute-path rejection.
- Commit `bd6fc06` is pushed. Actions run `38746838245` failed in Simulator XCTest: 4 of 5 tests passed, but `testBundleAndWritableResourceRootsStaySeparate` could not locate the checked-in fixture (`NSBundle pathForResource` returned nil). Root cause: `resources:` is not an XcodeGen target property and was silently ignored. The correction now places the fixture under `sources` with `buildPhase: resources`, the documented XcodeGen mechanism. Resource API Unicode/space/empty/missing/path-rejection test passed on the Simulator; the bundle test must be rerun.
- Local GCC C11 strict-warning + ASan/UBSan host checks, YAML/test-target/fixture checks, plist, README shell syntax, and `git diff --check` pass. The iOS Simulator test suite itself is not green until the corrected fixture is verified.
- No production HPL2 resource manager is connected to this helper yet. Review it as a minimal platform/file-access primitive, not a complete cache/archive/asset loading port. Local, unpushed test changes strengthen quaternion identity/normalization/composition-order assertions; host validation passed.
