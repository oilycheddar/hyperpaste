#!/bin/bash
set -e

APP_NAME="HyperPaste"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
VERSION="${1:-1.0.0}"
SPARKLE_SIGN="/tmp/Sparkle-2.6.0/bin/sign_update"
DEVELOPER_ID="Developer ID Application: George Visan (X2FNF3V2HX)"

echo "==> Building $APP_NAME v$VERSION..."
swift build -c release

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

# Copy Sparkle framework
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
cp -R ".build/arm64-apple-macosx/release/Sparkle.framework" "$APP_BUNDLE/Contents/Frameworks/"

echo "==> Setting version to $VERSION..."
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Code signing with Developer ID..."
codesign --force --deep --options runtime --timestamp -s "$DEVELOPER_ID" "$APP_BUNDLE"

echo "==> Creating update zip..."
RELEASE_ZIP="$APP_NAME-$VERSION.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_ZIP"

echo "==> Signing with Sparkle EdDSA..."
if [ -x "$SPARKLE_SIGN" ]; then
    SIGNATURE=$("$SPARKLE_SIGN" "$RELEASE_ZIP")
    echo ""
    echo "Add this to appcast.xml enclosure:"
    echo "  $SIGNATURE"
else
    echo "WARNING: Sparkle sign_update not found at $SPARKLE_SIGN"
    echo "File size: $(stat -f%z "$RELEASE_ZIP") bytes"
fi

echo ""
echo "==> Notarizing..."
xcrun notarytool submit "$RELEASE_ZIP" --keychain-profile "notary-profile" --wait
xcrun stapler staple "$APP_BUNDLE"

echo ""
echo "Done! v$VERSION"
echo "  App:  $APP_BUNDLE"
echo "  Zip:  $RELEASE_ZIP"
echo ""
echo "Next: update appcast.xml with the signature above, then deploy."
