# SDL3 iOS Touch PoC

A small, asset-free iOS app used to verify SDL's iOS lifecycle, touch input, and Xcode build path before attempting to port HPL2. It does not include or use Amnesia code or commercial game assets.

The app fills the display with blue. Holding a touch changes it to red-orange; lifting or cancelling the touch restores blue. It pauses drawing on `SDL_EVENT_WILL_ENTER_BACKGROUND` and resumes on `SDL_EVENT_DID_ENTER_FOREGROUND`.

## Pinned SDL dependency

This project uses SDL **3.4.18**, a stable SDL3 release with official iOS support. SDL itself is not vendored. `scripts/fetch-sdl.sh` downloads the official `SDL3-3.4.18.dmg`, checks its SHA-256 against the digest published in the SDL GitHub release metadata, mounts it read-only, and copies out the official `SDL3.xcframework`.

The script requires macOS tools (`hdiutil`, `ditto`, `shasum`) and `curl`. It never downloads or includes Amnesia assets.

## Build locally on a Mac

Requirements: macOS, Xcode with the iOS SDK, and Homebrew.

From the repository root:

```sh
cd ios-sdl-poc
brew install xcodegen
./scripts/fetch-sdl.sh
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

The repository-root workflow at `.github/workflows/ios-sdl-poc.yml` runs on `macos-15`. It installs XcodeGen, runs the same SDL download and checksum verification, generates the Xcode project, then calls `xcodebuild` for both `generic/platform=iOS` and `generic/platform=iOS Simulator`. The unsigned `.app` products are uploaded as workflow artifacts.

No signing secrets are required for these compile-only jobs. The workflow does **not** claim to install the app on a phone, create an IPA, or submit to TestFlight. Installing on a physical iPhone requires signing and provisioning; TestFlight distribution additionally requires Apple Developer Program membership.

## Files

- `Sources/main.c` — SDL renderer, touch state, and lifecycle handling.
- `project.yml` — XcodeGen definition for the native iOS app target.
- `Info.plist` — launch-screen and full-screen configuration.
- `scripts/fetch-sdl.sh` — pinned SDL release download, hash verification, and xcframework extraction.
- `.github/workflows/ios-sdl-poc.yml` — macOS/Xcode build workflow (at the repository root so GitHub Actions discovers it).
