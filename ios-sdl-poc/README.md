# SDL3 iOS Touch PoC

An asset-free iOS project for SDL lifecycle/touch and an incremental HPL2-to-Metal path. The app still does **not** initialize Amnesia. It records a clamped monotonic frame delta, pauses across background transitions, logs failures, and resolves separate bundle-resource and writable-data roots. The current unverified app change replaces `SDL_Renderer` with `SDL_Metal_CreateView` plus an app-owned Metal command queue/pipeline on SDL's Metal layer, so SDL and HPL2 code do not compete for the drawable. The intended visible surface keeps the blue/red touch background and draws an unlit indexed quad populated with an HPL2-format fixture. That fixture is synthetic, not a shipped mesh or game scene; the new app path is pending Actions validation. Separate XCTest coverage exercises HPL2 `iVertexBuffer` metadata → zero-copy descriptors → Metal buffer upload → MSL indexed draw/readback. No full engine or commercial game assets are vendored.

The pending Metal window presenter clears blue; holding a touch changes the clear to red-orange; lifting or cancelling restores blue. It draws a white indexed quad with separate HPL2-style position/normal/color/UV/tangent arrays, a UInt32 index buffer, Metal vertex descriptor, HPL2-to-Metal matrix conversion, and an alpha-tested Z pass followed by an equal-depth color pass. This is unlit synthetic geometry and a white texture, not HPL2 `cRendererSimple`, a loaded game mesh, or Amnesia content. `SDL_AddEventWatch` pauses rendering on background events and resumes after foreground activation; atomics bridge the possibly cross-thread watcher. `EngineHostCore` is not connected to HPL2 simulation. SDL supplies/logs separate bundle-resource and writable-data roots.

## Pinned SDL dependency

This project uses SDL **3.4.18**, a stable SDL3 release with official iOS support. SDL itself is not vendored. `scripts/fetch-sdl.sh` downloads the official `SDL3-3.4.18.dmg`, checks its SHA-256 against the digest published in the SDL GitHub release metadata, mounts it read-only, and copies out the official `SDL3.xcframework`.

The script requires macOS tools (`hdiutil`, `ditto`, `shasum`) and `curl`. It never downloads or includes Amnesia assets.

## HPL2 core-math smoke tests

The separate `HPL2CRC`, `HPL2Quaternion`, and `HPL2Math` static libraries compile real HPL2 code from **FrictionalGames/AmnesiaTheDarkDescent** at pinned commit `acc95cdedd6c94db89dc924eb9afa23185df562f`. This is the inspected upstream revision; pinning its SHA prevents CI from silently following a moving branch. Only selected implementation files and their compile-time header closure are sparsely checked out and staged under ignored `EngineSource/` for the build. No full engine, desktop dependency binaries, FBX SDK, or game assets are added to this repository or uploaded as an artifact.

The first test exercises `CRC.cpp`: CRC of `123456789` with key `0x04C11DB7` must be `0x89A1897F`; it also compares byte-wise input with `PutData()` and checks `Done()` reset behavior. `CRC.cpp` includes only `math/CRC.h`, whose only include is `<cstddef>`.

The next tests exercise `Quaternion.cpp`, an HPL2 rotation component used by the engine's math/camera transforms. Its compiler-discovered header closure includes HPL2 math, graphics-type, and system-type headers (`Math.h`, `MathTypes.h`, `Matrix.h`, vectors, `BoundingVolume.h`, `GraphicsTypes.h`, `Color.h`, and low-level/system declarations), but no platform implementation or external library. Assertions cover a normalized 90-degree Z-axis rotation, same-axis composition, matrix round-tripping, identity/normalization, and noncommuting X/Z rotation products against HPL2's Hamilton multiplication order. This upstream `Normalize()` divides by the norm without guarding a zero-length quaternion, so tests use nonzero quaternions rather than implying the zero case is supported; angle-axis construction also requires a unit axis.

`HPL2Math` compiles the upstream `Math.cpp` and `MathTypes.cpp`. Their compiler-discovered closure has 18 HPL2 headers, including `Frustum.h` and `VertexBuffer.h`; the isolated smoke target does not add renderer or platform implementation sources. Its test calls HPL2's own `cMath::MatrixTranslate`, `MatrixRotateZ`, and `MatrixMul` to assert translation and the positive-Z X-to-Y convention. No transform implementation is copied into the test.

The standalone `IOSMetalTriangleProbe` remains a separate test-only graphics experiment: it creates a Metal device, runtime-compiles embedded MSL, clears an offscreen RGBA8 texture, draws a triangle, and checks pixel readback, invalid/oversized dimensions, and repeated rendering. It is excluded from the SDL app target. Separately, `HPL2MetalMeshAdapter`/`HPL2MetalMeshUploader`/`HPL2MetalMeshDraw` and the matrix/state adapters exercise HPL2-shaped vertex data and a synthetic indexed Metal quad. These are unit/integration probes only; the unlit shader is not HPL2's GLSL material path and no Amnesia scene is loaded.

GitHub Actions compiles the CRC, Quaternion, Math and HPL2 Metal adapter/uploader/matrix/state/draw libraries for the iOS device SDK, and runs core graphics tests plus a screenshot-based UI test on an **iOS Simulator**. Latest completed state run `38867486652` passed 25 core/adapter/matrix/state tests and the earlier SDL_Renderer screenshot test; the current `SDL_Metal_CreateView` app/presenter changes have not yet been built or run by Actions. Simulator validation is not a physical-iPhone test. No Amnesia scene is loaded. The upstream implementation carries GPL-3.0 notices; preserve them and account for that license if distributing a combined binary.

## Build locally on a Mac

Requirements: macOS, Xcode with the iOS SDK, and Homebrew.

From the repository root:

```bash
cd ios-sdl-poc
brew install xcodegen
./scripts/fetch-sdl.sh

UPSTREAM_SHA=acc95cdedd6c94db89dc924eb9afa23185df562f
UPSTREAM_DIR=.build/upstream-amnesia
UPSTREAM_FILES=(
  HPL2/core/include/graphics/Color.h
  HPL2/core/include/graphics/GraphicsTypes.h
  HPL2/core/include/graphics/VertexBuffer.h
  HPL2/core/include/math/BoundingVolume.h
  HPL2/core/include/math/Frustum.h
  HPL2/core/include/math/CRC.h
  HPL2/core/include/math/Math.h
  HPL2/core/include/math/MathTypes.h
  HPL2/core/include/math/Matrix.h
  HPL2/core/include/math/MeshTypes.h
  HPL2/core/include/math/Quaternion.h
  HPL2/core/include/math/Vector2.h
  HPL2/core/include/math/Vector3.h
  HPL2/core/include/system/Container.h
  HPL2/core/include/system/LowLevelSystem.h
  HPL2/core/include/system/MemoryManager.h
  HPL2/core/include/system/SerializeClass.h
  HPL2/core/include/system/SystemTypes.h
  HPL2/core/sources/math/CRC.cpp
  HPL2/core/sources/math/Math.cpp
  HPL2/core/sources/math/MathTypes.cpp
  HPL2/core/sources/math/Quaternion.cpp
)
git clone --filter=blob:none --no-checkout \
  https://github.com/FrictionalGames/AmnesiaTheDarkDescent.git \
  "${UPSTREAM_DIR}"
git -C "${UPSTREAM_DIR}" sparse-checkout init --no-cone
git -C "${UPSTREAM_DIR}" sparse-checkout set --no-cone "${UPSTREAM_FILES[@]}"
git -C "${UPSTREAM_DIR}" checkout --detach "${UPSTREAM_SHA}"
for relative_path in "${UPSTREAM_FILES[@]}"; do
  destination="EngineSource/${relative_path}"
  mkdir -p "$(dirname "${destination}")"
  cp "${UPSTREAM_DIR}/${relative_path}" "${destination}"
done

xcodegen generate --spec project.yml

# Compile an unsigned iPhone/iPad device target.
xcodebuild \
  -project SDLTouchPoC.xcodeproj \
  -scheme SDLTouchPoC \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

# Also compile an unsigned simulator target.
xcodebuild \
  -project SDLTouchPoC.xcodeproj \
  -scheme SDLTouchPoC \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Products are expected under `.build/DerivedData/Build/Products/Debug-iphoneos/SDLTouchPoC.app` and `.build/DerivedData/Build/Products/Debug-iphonesimulator/SDLTouchPoC.app` respectively. These commands compile but do not sign the app; the device build is not installable until it is signed with an Apple development identity and a matching provisioning profile.

To use another Xcode version or signing identity, change the Xcode project/build settings as needed. The project has no Apple Developer credentials embedded in it.

## GitHub Actions

The repository-root workflow at `.github/workflows/ios-sdl-poc.yml` runs on `macos-15`. It builds unsigned iOS device/Simulator targets and IPA, compiles the pinned HPL2/Metal libraries for the device SDK, runs XCTest suites and a UI test that checks a screenshot for bright center geometry on an available iPhone Simulator, and uploads `.xcresult` bundles (including on test failure). The current SDL_Metal_CreateView presenter changes are pending their first run.

GitHub Actions does not attach a physical iPhone. HPL2 CRC, Quaternion, and matrix execution is simulator-only; the iOS device-SDK step compiles the libraries but does not run them on hardware. The workflow does not boot HPL2 or render an Amnesia scene. The SDL device app artifact remains unsigned and is not installable until signed with a valid Apple identity and matching provisioning profile. TestFlight distribution additionally requires Apple Developer Program membership. When a published GitHub Release exists, the workflow also attaches the SDL IPA to the latest release; it never creates a release.

## Files

- `Sources/main.c` — SDL window/touch/lifecycle/frame-clock host; it calls the Metal presenter and owns no SDL_Renderer.
- `Sources/HPL2MetalWindowPresenter.mm` — obtains the SDL Metal view/layer, acquires/presents drawables, and runs the HPL2-format fixture pass. This remains a synthetic test mesh, not game content.
- `Sources/HPL2MetalMeshAdapter.{h,cpp}` — checked HPL2 vertex/index metadata views; does not copy host arrays.
- `Sources/HPL2MetalMeshUploader.{h,mm}` — creates Metal-owned vertex/index buffers and a descriptor from validated views.
- `Sources/HPL2MetalMatrixAdapter.{h,cpp}` — HPL2 matrix storage conversion and OpenGL-to-Metal clip-depth remap.
- `Sources/HPL2MetalRenderStateAdapter.{h,mm}` — HPL2 depth/cull/blend/channel/alpha/sampler state mapping; explicitly rejects unsupported legacy clamp modes.
- `Sources/HPL2MetalMeshDraw.{h,mm}` — unlit MSL triangle-list pipeline/encoder; not HPL2 GLSL or deferred renderer.
- `Sources/IOSMetalTriangleProbe.[h/mm]` — separate test-only offscreen Metal pixel probe; excluded from the SDL app.
- `Tests/` — HPL2 math/resource/clock regressions, Metal probe, adapter/uploader/state/matrix/draw tests, and UI screenshot test.
- `project.yml` — XcodeGen definitions for the SDL app and HPL2 core-math smoke targets.
- `Info.plist` — launch-screen and full-screen configuration.
- `scripts/fetch-sdl.sh` — pinned SDL release download, hash verification, and xcframework extraction.
- `.github/workflows/ios-sdl-poc.yml` — macOS/Xcode build workflow (at the repository root so GitHub Actions discovers it).
