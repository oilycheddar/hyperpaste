#!/bin/bash
set -e

APP_NAME="HyperPaste"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "==> Building $APP_NAME..."
swift build -c release

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

echo "==> Ad-hoc code signing..."
codesign --force --deep -s - "$APP_BUNDLE"

echo "==> Creating distributable zip..."
zip -r "$APP_NAME.zip" "$APP_BUNDLE"

echo ""
echo "Done!"
echo "  App:  $APP_BUNDLE"
echo "  Zip:  $APP_NAME.zip"
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To install: drag $APP_BUNDLE to /Applications"
