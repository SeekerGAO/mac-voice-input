#!/usr/bin/env bash

set -euo pipefail

APP_NAME="MacVoiceInput"
VERSION="${1:-dev}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
BUILD_APP_PATH=".build/${BUILD_CONFIG}/${APP_NAME}.app"
DIST_DIR="dist"
ARCHIVE_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

echo "Building ${APP_NAME} (${VERSION})"
make build CONFIG="${BUILD_CONFIG}"

if [[ ! -d "${BUILD_APP_PATH}" ]]; then
  echo "Expected app bundle not found at ${BUILD_APP_PATH}" >&2
  exit 1
fi

if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  echo "Signing app bundle with Developer ID identity"
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "${APPLE_SIGNING_IDENTITY}" \
    "${BUILD_APP_PATH}"
fi

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  NOTARY_ARCHIVE_PATH="${RUNNER_TEMP:-/tmp}/${APP_NAME}-notarize-${VERSION}.zip"
  echo "Preparing notarization archive"
  ditto -c -k --sequesterRsrc --keepParent "${BUILD_APP_PATH}" "${NOTARY_ARCHIVE_PATH}"

  echo "Submitting app for notarization"
  xcrun notarytool submit "${NOTARY_ARCHIVE_PATH}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --team-id "${APPLE_TEAM_ID}" \
    --wait

  echo "Stapling notarization ticket"
  xcrun stapler staple "${BUILD_APP_PATH}"
fi

mkdir -p "${DIST_DIR}"
rm -f "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"

echo "Creating distributable archive"
ditto -c -k --sequesterRsrc --keepParent "${BUILD_APP_PATH}" "${ARCHIVE_PATH}"
shasum -a 256 "${ARCHIVE_PATH}" > "${CHECKSUM_PATH}"

echo "Release assets:"
ls -lh "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"
