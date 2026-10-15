#!/usr/bin/env bash
set -euo pipefail

SDL_VERSION="3.4.18"
SDL_SHA256="c1adf3da91108dbc3e4205da5dacebc203085d283fa89e86eb2c889abd03a853"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${POC_DIR}/Vendor"
FRAMEWORK_DIR="${VENDOR_DIR}/SDL3.xcframework"
WORK_DIR="$(mktemp -d)"
MOUNT_DIR="${WORK_DIR}/mount"
MOUNTED=0

cleanup() {
    if [[ "${MOUNTED}" == "1" ]]; then
        hdiutil detach "${MOUNT_DIR}" -quiet || true
    fi
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if [[ -d "${FRAMEWORK_DIR}" ]]; then
    echo "SDL3.xcframework already exists at ${FRAMEWORK_DIR}"
    exit 0
fi

mkdir -p "${VENDOR_DIR}" "${MOUNT_DIR}"
DMG_PATH="${WORK_DIR}/SDL3-${SDL_VERSION}.dmg"
DMG_URL="https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL3-${SDL_VERSION}.dmg"

curl --fail --location --retry 3 "${DMG_URL}" --output "${DMG_PATH}"
printf '%s  %s\n' "${SDL_SHA256}" "${DMG_PATH}" | shasum --check --algorithm 256

hdiutil attach -quiet -nobrowse -readonly -mountpoint "${MOUNT_DIR}" "${DMG_PATH}"
MOUNTED=1

XCFRAMEWORK_PATH="$(find "${MOUNT_DIR}" -type d -name SDL3.xcframework -print -quit)"
if [[ -z "${XCFRAMEWORK_PATH}" ]]; then
    echo "SDL3.xcframework was not found in the official SDL ${SDL_VERSION} disk image" >&2
    exit 1
fi

ditto "${XCFRAMEWORK_PATH}" "${FRAMEWORK_DIR}"
test -d "${FRAMEWORK_DIR}"
echo "Installed verified SDL ${SDL_VERSION} xcframework at ${FRAMEWORK_DIR}"
