#!/bin/bash

# This script fixes the archive Info.plist by adding ApplicationProperties
# Required because Xcode 26 beta doesn't add this automatically

ARCHIVE_PATH="${ARCHIVE_PATH:-$1}"

if [ -z "$ARCHIVE_PATH" ]; then
    echo "Error: No archive path provided"
    exit 1
fi

APP_PATH="$ARCHIVE_PATH/Products/Applications/Habitto.app"
ARCHIVE_PLIST="$ARCHIVE_PATH/Info.plist"
APP_PLIST="$APP_PATH/Info.plist"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Extract values from the app
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PLIST")
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PLIST")

# Get signing identity
SIGNING_ID=$(codesign -dv "$APP_PATH" 2>&1 | grep "Authority=" | head -1 | sed 's/Authority=//')

# Get team ID from provisioning profile
TEAM_ID=$(security cms -D -i "$APP_PATH/embedded.mobileprovision" 2>/dev/null | plutil -extract TeamIdentifier.0 raw -)

echo "Adding ApplicationProperties to archive..."
echo "  Bundle ID: $BUNDLE_ID"
echo "  Version: $VERSION"
echo "  Build: $BUILD"
echo "  Signing Identity: $SIGNING_ID"
echo "  Team: $TEAM_ID"

# Add ApplicationProperties to archive Info.plist
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties dict" "$ARCHIVE_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:ApplicationPath string 'Applications/Habitto.app'" "$ARCHIVE_PLIST"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:Architectures array" "$ARCHIVE_PLIST"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:Architectures:0 string 'arm64'" "$ARCHIVE_PLIST"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleIdentifier string '$BUNDLE_ID'" "$ARCHIVE_PLIST"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleShortVersionString string '$VERSION'" "$ARCHIVE_PLIST"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleVersion string '$BUILD'" "$ARCHIVE_PLIST"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:SigningIdentity string '$SIGNING_ID'" "$ARCHIVE_PLIST"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:Team string '$TEAM_ID'" "$ARCHIVE_PLIST"

echo "✅ Archive fixed successfully!"

