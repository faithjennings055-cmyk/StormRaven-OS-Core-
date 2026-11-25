#!/usr/bin/env bash
# StormRaven OS: Ymir Edition (v3.9.0) — Cloud macOS & Local Mac VM One-Command Xcode Archive & Code-Signer
# Founder: Dr. Justin Jennings ("Faith" / "Mr. Stormraven")
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
BUNDLE_ID="${BUNDLE_ID:-org.starforge.stormraven.os}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "[StormRaven iOS] Building StormRavenCompanion in $PROJECT_DIR (Bundle ID: $BUNDLE_ID)..."

# -----------------------------------------------------------------------------
# Three signing paths, checked in order.
#
#   1. App Store Connect API key  -> no Mac, no manual cert. Xcode creates the
#      distribution certificate and provisioning profile itself via
#      -allowProvisioningUpdates. This is the only path that works for someone
#      with no access to a Mac keychain, so it is checked first.
#   2. .p12 + .mobileprovision    -> manual signing with an existing cert.
#   3. Neither                   -> unsigned ad-hoc build, installable only via
#      AltStore/Sideloadly with the user's own certificate. Always a fallback,
#      never something to report as a signed release.
# -----------------------------------------------------------------------------
USE_ASC_KEY=0
if [[ -n "${APPLE_ASC_KEY_ID:-}" && -n "${APPLE_ASC_ISSUER_ID:-}" && -n "${APPLE_ASC_KEY_P8_BASE64:-}" ]]; then
  USE_ASC_KEY=1
  echo "[StormRaven iOS] Using App Store Connect API key (key id ${APPLE_ASC_KEY_ID})"
  if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "[StormRaven iOS] ERROR: APPLE_TEAM_ID is required alongside the API key." >&2
    exit 1
  fi
  ASC_KEY_DIR="$BUILD_DIR/asc"
  mkdir -p "$ASC_KEY_DIR"
  printf '%s' "$APPLE_ASC_KEY_P8_BASE64" | base64 --decode > "$ASC_KEY_DIR/AuthKey_${APPLE_ASC_KEY_ID}.p8"
  chmod 600 "$ASC_KEY_DIR/AuthKey_${APPLE_ASC_KEY_ID}.p8"
fi

if [[ "$USE_ASC_KEY" -eq 1 ]]; then
  echo "[StormRaven iOS] Archiving with automatic provisioning (Xcode manages cert + profile)..."
  xcodebuild -project "$PROJECT_DIR/StormRavenCompanion.xcodeproj" \
    -scheme StormRavenCompanion \
    -configuration Release \
    -sdk iphoneos \
    -archivePath "$BUILD_DIR/StormRavenCompanion.xcarchive" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_DIR/AuthKey_${APPLE_ASC_KEY_ID}.p8" \
    -authenticationKeyID "$APPLE_ASC_KEY_ID" \
    -authenticationKeyIssuerID "$APPLE_ASC_ISSUER_ID" \
    archive

  cat <<PLIST > "$BUILD_DIR/ExportOptions.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${EXPORT_METHOD:-development}</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
PLIST

  xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/StormRavenCompanion.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR/export" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_DIR/AuthKey_${APPLE_ASC_KEY_ID}.p8" \
    -authenticationKeyID "$APPLE_ASC_KEY_ID" \
    -authenticationKeyIssuerID "$APPLE_ASC_ISSUER_ID"

  cp "$BUILD_DIR/export/"*.ipa "$BUILD_DIR/StormRavenOS.ipa"
  rm -rf "$ASC_KEY_DIR"
  SIGNED=1
elif [[ -n "${APPLE_P12_BASE64:-}" && -n "${APPLE_PROVISION_BASE64:-}" ]]; then
  echo "[StormRaven iOS] Importing Apple Developer signing certificate & provisioning profile into temporary keychain..."
  KEYCHAIN_PASS="$(openssl rand -hex 16)"
  security create-keychain -p "$KEYCHAIN_PASS" stormraven-build.keychain
  security default-keychain -s stormraven-build.keychain
  security unlock-keychain -p "$KEYCHAIN_PASS" stormraven-build.keychain
  security set-keychain-settings -t 3600 -u stormraven-build.keychain

  echo "$APPLE_P12_BASE64" | base64 --decode > "$BUILD_DIR/cert.p12"
  security import "$BUILD_DIR/cert.p12" -k stormraven-build.keychain -P "${APPLE_P12_PASSWORD:-}" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASS" stormraven-build.keychain

  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  echo "$APPLE_PROVISION_BASE64" | base64 --decode > "$HOME/Library/MobileDevice/Provisioning Profiles/stormraven.mobileprovision"
  rm -f "$BUILD_DIR/cert.p12"

  xcodebuild -project "$PROJECT_DIR/StormRavenCompanion.xcodeproj" \
    -scheme StormRavenCompanion \
    -configuration Release \
    -sdk iphoneos \
    -archivePath "$BUILD_DIR/StormRavenCompanion.xcarchive" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    archive

  cat <<PLIST > "$BUILD_DIR/ExportOptions.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
PLIST

  xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/StormRavenCompanion.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR/export"

  cp "$BUILD_DIR/export/"*.ipa "$BUILD_DIR/StormRavenOS.ipa"
  SIGNED=1
else
  SIGNED=0
  echo "[StormRaven iOS] Compiling native arm64 iOS bundle with ad-hoc Mach-O signature (ready for AltStore / Sideloadly / ldid / Team signing)..."
  xcodebuild -project "$PROJECT_DIR/StormRavenCompanion.xcodeproj" \
    -scheme StormRavenCompanion \
    -configuration Release \
    -sdk iphoneos \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

  APP_PATH="$(find "$BUILD_DIR/DerivedData" -name "StormRavenCompanion.app" -type d | head -n 1)"
  mkdir -p "$BUILD_DIR/Payload"
  cp -R "$APP_PATH" "$BUILD_DIR/Payload/StormRavenOS.app"
  # Apply ad-hoc Mach-O signature so iOS arm64 binary has valid LC_CODE_SIGNATURE load command
  codesign --force --deep --sign - "$BUILD_DIR/Payload/StormRavenOS.app"
  (cd "$BUILD_DIR" && zip -qry "$BUILD_DIR/StormRavenOS.ipa" Payload)
fi

(cd "$BUILD_DIR" && shasum -a 256 StormRavenOS.ipa > StormRavenOS.ipa.sha256)
if [[ "${SIGNED:-0}" -eq 1 ]]; then
  echo "[StormRaven iOS] Built & SIGNED: $BUILD_DIR/StormRavenOS.ipa"
else
  echo "[StormRaven iOS] WARNING: built UNSIGNED (ad-hoc). Installs only via AltStore/Sideloadly with your own certificate." >&2
  echo "[StormRaven iOS]          Provide APPLE_ASC_KEY_ID + APPLE_ASC_ISSUER_ID + APPLE_ASC_KEY_P8_BASE64 (or a .p12 + profile) for a real signed build." >&2
fi
cat "$BUILD_DIR/StormRavenOS.ipa.sha256"
