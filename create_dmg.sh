#!/bin/bash

APP_NAME="Synco"
APP_SOURCE="build/macos/Build/Products/Release/synco.app"
DMG_NAME="Synco-macOS-v1.0.0.dmg"
VOL_NAME="Synco Installer"

# Check if app exists
if [ ! -d "$APP_SOURCE" ]; then
    echo "Error: App not found at $APP_SOURCE"
    echo "Please run 'flutter build macos --release' first."
    exit 1
fi

# Clean up previous attempts
rm -f "$DMG_NAME"
rm -rf "tmp_dmg"

# Create temp folder for DMG content
mkdir -p "tmp_dmg"

# Copy App
echo "Copying app..."
cp -r "$APP_SOURCE" "tmp_dmg/"

# Create /Applications link
echo "Creating Applications link..."
ln -s /Applications "tmp_dmg/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$VOL_NAME" -srcfolder "tmp_dmg" -ov -format UDZO "$DMG_NAME"

# Clean up
rm -rf "tmp_dmg"

echo "✅ DMG created: $DMG_NAME"
