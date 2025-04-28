#!/bin/bash

echo "Building ClipboardManager..."

# Build the application in release mode
swift build -c release

# Create app structure
APP_NAME="ClipboardManager.app"
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# Copy executable
cp .build/release/ClipboardManager "$APP_NAME/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_NAME/Contents/"

# Copy Icon
cp IconConversion/ClipboardManager.icns "$APP_NAME/Contents/Resources/"

# Remove the old Assets.xcassets - not needed for icns file approach
# cp -R Assets.xcassets "$APP_NAME/Contents/Resources/"

echo "App bundle created: $APP_NAME"
echo "To run, double-click the app or run:"
echo "open $APP_NAME" 