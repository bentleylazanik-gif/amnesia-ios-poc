# SDL3 iOS Touch PoC

A small, asset-free iOS project used to verify SDL's iOS lifecycle, touch input, and Xcode build path before attempting to port HPL2. The `SDLTouchPoC` app remains independent of Amnesia. A separate smoke-test target compiles one pinned HPL2 core source file during CI; no full engine or commercial game assets are vendored.

The app fills the display with blue. Holding a touch changes it to red-orange; lifting or cancelling the touch restores blue. It pauses drawing on `SDL_EVENT_WILL_ENTER_BACKGROUND` and resumes on `SDL_EVENT_DID_ENTER_FOREGROUND`.

## Pinned SDL dependency

This project uses SDL **3.4.18**, a stable SDL3 release with official iOS support. SDL itself is not vendored. `scripts/fetch-sdl.sh` downloads the official `SDL3-3.4.18.dmg`, checks its SHA-256 against the digest published in the SDL GitHub release metadata, mounts it read-only, and copies out the official `SDL3.xcframework`.

The script requires macOS tools (`hdiutil`, `ditto`, `shasum`) and `curl`. It never downloads or includes Amnesia assets.

## HPL2 CRC core smoke test

The separate `HPL2CRC` library and `HPL2CRCTests` iOS test target compile and exercise only these upstream files:

- `HPL2/core/include/math/CRC.h`
- `HPL2/core/sources/math/CRC.cpp`

GitHub Actions checks out **FrictionalGames/AmnesiaTheDarkDescent** at commit `acc95cdedd6c94db89dc924eb9afa23185df562f` and sparsely checks out only those two files. This is the immutable upstream revision inspected for this test; pinning it prevents the smoke test source from silently changing with `master`. The source is staged under the ignored `EngineSource/` directory for the build only; it is not committed to this repository. No other engine source, desktop dependency, FBX SDK, or game asset is fetched into the test target.

The deterministic test computes the CRC of `123456789` using key `0x04C11DB7` and expects `0x89A1897F`. It also checks that byte-by-byte input matches `PutData()` and that `Done()` resets the accumulator. `CRC.cpp` includes only `math/CRC.h`, whose only include is `<cstddef>`; it does not depend on SDL, platform APIs, graphics, or third-party libraries. The upstream CRC source is GPL-3.0; retain its license notices and account for that license if distributing a combined binary.

GitHub Actions separately compiles the `HPL2CRC` static library against the iOS device SDK and runs the XCTest on an **iOS Simulator**. The simulator test is not a physical iPhone test and does not boot HPL2 or the Amnesia game.

## Build locally on a Mac

Requirements: macOS, Xcode with the iOS SDK, and Homebrew.

From the repository root:

```sh
cd ios-sdl-poc
brew install xcodegen
./scripts/fetch-sdl.sh

git clone --filter=blob:none --no-checkout --branch master \
  https://github.com/FrictionalGames/AmnesiaTheDarkDescent.git \
  .build/upstream-amnesia
git -C .build/upstream-amnesia sparse-checkout init --no-cone
git -C .build/upstream-amnesia sparse-checkout set --no-cone \
  /HPL2/core/include/math/CRC.h \
  /HPL2/core/sources/math/CRC.cpp
git -C .build/upstream-amnesia checkout --detach \
  acc95cdedd6c94db89dc924eb9afa23185df562f
mkdir -p EngineSource/HPL2/core/include/math \
  EngineSource/HPL2/core/sources/math
cp .build/upstream-amnesia/HPL2/core/include/math/CRC.h \
  EngineSource/HPL2/core/include/math/CRC.h
cp .build/upstream-amnesia/HPL2/core/sources/math/CRC.cpp \
  EngineSource/HPL2/core/sources/math/CRC.cpp

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

The repository-root workflow at `.github/workflows/ios-sdl-poc.yml` runs on `macos-15`. It preserves the existing SDL3 device and simulator builds, then compiles the HPL2 CRC static library for the iOS device SDK and runs its deterministic XCTest on an available iPhone Simulator. It also packages and uploads the unsigned SDL app IPA and uploads the existing app products.

GitHub Actions does not attach a physical iPhone. The HPL2 CRC test result is simulator-only; the device-SDK step is compile-only. The SDL device app artifact is unsigned and is not installable until signed with a valid Apple identity and matching provisioning profile. TestFlight distribution additionally requires Apple Developer Program membership. When a published GitHub Release exists, the workflow also attaches the SDL IPA to the latest release; it never creates a release.

## Files

- `Sources/main.c` — SDL renderer, touch state, and lifecycle handling.
- `Tests/` — isolated HPL2 CRC XCTest host and deterministic test.
- `project.yml` — XcodeGen definitions for the SDL app and HPL2 CRC test targets.
- `Info.plist` — launch-screen and full-screen configuration.
- `scripts/fetch-sdl.sh` — pinned SDL release download, hash verification, and xcframework extraction.
- `.github/workflows/ios-sdl-poc.yml` — macOS/Xcode build workflow (at the repository root so GitHub Actions discovers it).
