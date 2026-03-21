#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# Zcreen Release Script
#
# Usage:
#   ./Scripts/release.sh <version>
#
# Reads from .env.local (gitignored, never committed):
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   NOTARIZE_PROFILE="Zcreen"      # keychain profile name
#
# First-time setup:
#   1. Install Developer ID certificate in Keychain
#   2. Run: xcrun notarytool store-credentials "Zcreen"
#      (stores Apple ID + app-specific password in Keychain)
#   3. Create .env.local with the two variables above
# ──────────────────────────────────────────────────────────────

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

VERSION="${1:?Usage: release.sh <version>}"
APP_NAME="Zcreen"

# Load local config
if [ -f .env.local ]; then
    # shellcheck disable=SC1091
    source .env.local
else
    echo "ERROR: .env.local not found. Create it with:"
    echo '  SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"'
    echo '  NOTARIZE_PROFILE="Zcreen"'
    exit 1
fi

SIGN_IDENTITY="${SIGN_IDENTITY:?SIGN_IDENTITY not set in .env.local}"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-}"

echo "==> Release: ${APP_NAME} v${VERSION}"
echo "    Identity: ${SIGN_IDENTITY}"

# Step 1: Update version in Info.plist
echo "==> Updating version to ${VERSION}..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "Sources/Zcreen/App/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "Sources/Zcreen/App/Info.plist"

# Step 2: Build and bundle (with Developer ID signing)
echo "==> Building app bundle..."
bash Scripts/bundle.sh "${SIGN_IDENTITY}"

# Step 3: Create release zip
ZIP_NAME="${APP_NAME}-v${VERSION}.zip"
echo "==> Creating ${ZIP_NAME}..."
ditto -c -k --keepParent "${APP_NAME}.app" "${ZIP_NAME}"

# Step 4: Notarize (if profile is configured)
if [ -n "${NOTARIZE_PROFILE}" ]; then
    echo "==> Notarizing with profile '${NOTARIZE_PROFILE}'..."
    xcrun notarytool submit "${ZIP_NAME}" \
        --keychain-profile "${NOTARIZE_PROFILE}" \
        --wait

    echo "==> Stapling..."
    xcrun stapler staple "${APP_NAME}.app"

    # Re-create zip with stapled ticket
    rm -f "${ZIP_NAME}"
    ditto -c -k --keepParent "${APP_NAME}.app" "${ZIP_NAME}"
    echo "==> Notarization complete."
else
    echo "==> Skipping notarization (NOTARIZE_PROFILE not set)"
fi

echo ""
echo "==> Release artifact ready: ${ZIP_NAME}"
echo ""
echo "Next steps:"
echo "  1. git add -A && git commit -m 'Release v${VERSION}'"
echo "  2. git tag v${VERSION}"
echo "  3. git push && git push --tags"
echo "  4. gh release create v${VERSION} ${ZIP_NAME} --title 'v${VERSION}' --generate-notes"
