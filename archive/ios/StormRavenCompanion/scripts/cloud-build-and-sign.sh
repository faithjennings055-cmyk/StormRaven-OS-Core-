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

# Optional: import Apple Developer Certificate (.p12) and Provisioning Profile if present in env
if [[ -n "${APPLE_P12_BASE64:-}" && -n "${APPLE_PROVISION_BASE64:-}" ]]; then
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
else
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
echo "[StormRaven iOS] Built & signed: $BUILD_DIR/StormRavenOS.ipa"
cat "$BUILD_DIR/StormRavenOS.ipa.sha256"
