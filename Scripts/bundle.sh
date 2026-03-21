#!/bin/bash
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

APP_NAME="Zcreen"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

# Optional: signing identity (pass as first argument)
SIGN_IDENTITY="${1:--}"

echo "==> Building release..."
swift build -c release

echo "==> Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy icon
if [ -f "Sources/Zcreen/App/AppIcon.icns" ]; then
    cp "Sources/Zcreen/App/AppIcon.icns" "${RESOURCES}/AppIcon.icns"
fi

# Copy Info.plist from source and add icon key
cp "Sources/Zcreen/App/Info.plist" "${CONTENTS}/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${CONTENTS}/Info.plist" 2>/dev/null || true

# Sign
echo "==> Signing with identity: ${SIGN_IDENTITY}"
if [ "${SIGN_IDENTITY}" = "-" ]; then
    codesign --force --sign - "${APP_BUNDLE}"
else
    codesign --force --options runtime --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
fi

echo "==> Done! App bundle: ${APP_BUNDLE}"
echo "    Run: open ${APP_BUNDLE}"
