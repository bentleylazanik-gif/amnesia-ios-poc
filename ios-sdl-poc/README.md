# SDL3 iOS Touch PoC

A small, asset-free iOS project used to verify SDL's iOS lifecycle, touch input, and Xcode build path before attempting to port HPL2. The `SDLTouchPoC` app remains independent of Amnesia. It now also records a clamped monotonic frame delta, pauses across background transitions, logs startup/render failures through SDL, tracks drawable pixel-size changes, and resolves separate bundle-resource and writable-data roots. Separate smoke tests compile pinned HPL2 CRC and quaternion source modules and test frame-clock and resource-file helpers; no full engine or commercial game assets are vendored.

The app fills the display with blue. Holding a touch changes it to red-orange; lifting or cancelling the touch restores blue. An `SDL_AddEventWatch` callback pauses drawing on background lifecycle events, resumes after foreground activation, and marks termination; atomic flags safely bridge SDL's possibly cross-thread watcher to the main frame callback. `EngineHostCore` computes monotonic frame deltas clamped to 250 ms and resets timing over suspension; this is a reusable timing foundation, not yet connected to HPL2 simulation. SDL supplies the app-bundle resource root and the separate app-writable data root, which are logged at startup.

## Pinned SDL dependency

This project uses SDL **3.4.18**, a stable SDL3 release with official iOS support. SDL itself is not vendored. `scripts/fetch-sdl.sh` downloads the official `SDL3-3.4.18.dmg`, checks its SHA-256 against the digest published in the SDL GitHub release metadata, mounts it read-only, and copies out the official `SDL3.xcframework`.

The script requires macOS tools (`hdiutil`, `ditto`, `shasum`) and `curl`. It never downloads or includes Amnesia assets.

## HPL2 core-math smoke tests

The separate `HPL2CRC`, `HPL2Quaternion`, and `HPL2Math` static libraries compile real HPL2 code from **FrictionalGames/AmnesiaTheDarkDescent** at pinned commit `acc95cdedd6c94db89dc924eb9afa23185df562f`. This is the inspected upstream revision; pinning its SHA prevents CI from silently following a moving branch. Only selected implementation files and their compile-time header closure are sparsely checked out and staged under ignored `EngineSource/` for the build. No full engine, desktop dependency binaries, FBX SDK, or game assets are added to this repository or uploaded as an artifact.

The first test exercises `CRC.cpp`: CRC of `123456789` with key `0x04C11DB7` must be `0x89A1897F`; it also compares byte-wise input with `PutData()` and checks `Done()` reset behavior. `CRC.cpp` includes only `math/CRC.h`, whose only include is `<cstddef>`.

The next tests exercise `Quaternion.cpp`, an HPL2 rotation component used by the engine's math/camera transforms. Its compiler-discovered header closure includes HPL2 math, graphics-type, and system-type headers (`Math.h`, `MathTypes.h`, `Matrix.h`, vectors, `BoundingVolume.h`, `GraphicsTypes.h`, `Color.h`, and low-level/system declarations), but no platform implementation or external library. Assertions cover a normalized 90-degree Z-axis rotation, same-axis composition, matrix round-tripping, identity/normalization, and noncommuting X/Z rotation products against HPL2's Hamilton multiplication order. This upstream `Normalize()` divides by the norm without guarding a zero-length quaternion, so tests use nonzero quaternions rather than implying the zero case is supported; angle-axis construction also requires a unit axis.

`HPL2Math` compiles the upstream `Math.cpp` and `MathTypes.cpp`. Their compiler-discovered closure has 18 HPL2 headers, including `Frustum.h` and `VertexBuffer.h`; the isolated smoke target does not add renderer or platform implementation sources. Its test calls HPL2's own `cMath::MatrixTranslate`, `MatrixRotateZ`, and `MatrixMul` to assert translation and the positive-Z X-to-Y convention. No transform implementation is copied into the test.

GitHub Actions compiles the CRC, Quaternion, and Math static libraries for the iOS device SDK and runs seven CRC, Quaternion, matrix, frame-clock, and resource-access XCTest methods on an **iOS Simulator**. This is not a physical-iPhone test and does not initialize HPL2, its renderer, or the Amnesia game. The upstream implementation carries GPL-3.0 notices; preserve them and account for that license if distributing a combined binary.

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

The repository-root workflow at `.github/workflows/ios-sdl-poc.yml` runs on `macos-15`. It preserves the SDL3 device and simulator builds, compiles the HPL2 CRC, Quaternion, and Math static libraries for the iOS device SDK, then runs the CRC, Quaternion, matrix, frame-clock, and resource-access tests on an available iPhone Simulator. It is configured to upload the Simulator `.xcresult` bundle (including on test failure), and packages/uploads the unsigned SDL app IPA and app products.

GitHub Actions does not attach a physical iPhone. HPL2 CRC and Quaternion execution is simulator-only; the iOS device-SDK step compiles the libraries but does not run them on hardware. The workflow does not boot HPL2 or render an Amnesia scene. The SDL device app artifact remains unsigned and is not installable until signed with a valid Apple identity and matching provisioning profile. TestFlight distribution additionally requires Apple Developer Program membership. When a published GitHub Release exists, the workflow also attaches the SDL IPA to the latest release; it never creates a release.

## Files

- `Sources/main.c` — SDL renderer, touch/lifecycle handling, app path setup, and structured diagnostics.
- `Sources/EngineHostCore.[ch]` — portable monotonic frame-clock helper used by the host and tested with deterministic timestamps.
- `Sources/EngineResourceAccess.[ch]` — UTF-8 relative-path construction and file reads with explicit error statuses.
- `Tests/` — isolated HPL2 CRC/Quaternion, frame-clock, and resource-access XCTest coverage.
- `project.yml` — XcodeGen definitions for the SDL app and HPL2 core-math smoke targets.
- `Info.plist` — launch-screen and full-screen configuration.
- `scripts/fetch-sdl.sh` — pinned SDL release download, hash verification, and xcframework extraction.
- `.github/workflows/ios-sdl-poc.yml` — macOS/Xcode build workflow (at the repository root so GitHub Actions discovers it).
