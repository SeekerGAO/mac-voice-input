#!/usr/bin/env bash

set -euo pipefail

APP_NAME="MacVoiceInput"
VERSION="${1:-dev}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
BUILD_APP_PATH=".build/${BUILD_CONFIG}/${APP_NAME}.app"
DIST_DIR="dist"
DMG_STAGING_DIR="${DIST_DIR}/dmg-root"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
ARCHIVE_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
DMG_CHECKSUM_PATH="${DMG_PATH}.sha256"
ZIP_CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

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
rm -rf "${DMG_STAGING_DIR}"
rm -f "${DMG_PATH}" "${DMG_CHECKSUM_PATH}" "${ARCHIVE_PATH}" "${ZIP_CHECKSUM_PATH}"

echo "Creating DMG staging directory"
mkdir -p "${DMG_STAGING_DIR}"
cp -R "${BUILD_APP_PATH}" "${DMG_STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING_DIR}/Applications"

echo "Creating distributable DMG"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "Creating fallback ZIP archive"
ditto -c -k --sequesterRsrc --keepParent "${BUILD_APP_PATH}" "${ARCHIVE_PATH}"
shasum -a 256 "${DMG_PATH}" > "${DMG_CHECKSUM_PATH}"
shasum -a 256 "${ARCHIVE_PATH}" > "${ZIP_CHECKSUM_PATH}"

echo "Release assets:"
ls -lh "${DMG_PATH}" "${DMG_CHECKSUM_PATH}" "${ARCHIVE_PATH}" "${ZIP_CHECKSUM_PATH}"
