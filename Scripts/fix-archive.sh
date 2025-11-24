#!/bin/bash

# This script fixes the archive Info.plist by adding ApplicationProperties
# Required because Xcode 26 beta doesn't add this automatically

# Log to a file to verify the script runs
LOG_FILE=~/Library/Logs/fix-archive.log
echo "$(date): Script started" >> "$LOG_FILE"
echo "ARCHIVE_PATH env: ${ARCHIVE_PATH:-not set}" >> "$LOG_FILE"
echo "First arg: ${1:-not set}" >> "$LOG_FILE"

# Try multiple ways to get the archive path
ARCHIVE_PATH="${ARCHIVE_PATH:-$1}"

# If ARCHIVE_PATH is not set, try to find the most recent archive
if [ -z "$ARCHIVE_PATH" ]; then
    # Look for the most recently created archive in the default location
    LATEST_ARCHIVE=$(find ~/Library/Developer/Xcode/Archives -type d -name "*.xcarchive" -maxdepth 2 -mtime -1 | sort -r | head -1)
    if [ -n "$LATEST_ARCHIVE" ]; then
        ARCHIVE_PATH="$LATEST_ARCHIVE"
        echo "Found archive: $ARCHIVE_PATH" >> "$LOG_FILE"
    else
        echo "Error: No archive path provided and could not find recent archive" >> "$LOG_FILE"
        exit 1
    fi
fi

echo "Using archive path: $ARCHIVE_PATH" >> "$LOG_FILE"

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

echo "Adding ApplicationProperties to archive (root level)..."
echo "  Bundle ID: $BUNDLE_ID"
echo "  Version: $VERSION"
echo "  Build: $BUILD"
echo "  Signing Identity: $SIGNING_ID"
echo "  Team: $TEAM_ID"

# Remove nested ApplicationProperties if it exists (from previous incorrect runs)
/usr/libexec/PlistBuddy -c "Delete :ApplicationProperties" "$ARCHIVE_PLIST" 2>/dev/null || true

# Add ApplicationProperties at ROOT level (not nested)
# This matches the structure of working archives from Xcode 16
/usr/libexec/PlistBuddy -c "Add :ApplicationPath string 'Applications/Habitto.app'" "$ARCHIVE_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :ApplicationPath 'Applications/Habitto.app'" "$ARCHIVE_PLIST"

/usr/libexec/PlistBuddy -c "Add :Architectures array" "$ARCHIVE_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :Architectures:0 string 'arm64'" "$ARCHIVE_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :Architectures:0 'arm64'" "$ARCHIVE_PLIST"

/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string '$BUNDLE_ID'" "$ARCHIVE_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier '$BUNDLE_ID'" "$ARCHIVE_PLIST"

/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string '$VERSION'" "$ARCHIVE_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString '$VERSION'" "$ARCHIVE_PLIST"

/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string '$BUILD'" "$ARCHIVE_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion '$BUILD'" "$ARCHIVE_PLIST"

if [ -n "$SIGNING_ID" ]; then
  /usr/libexec/PlistBuddy -c "Add :SigningIdentity string '$SIGNING_ID'" "$ARCHIVE_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :SigningIdentity '$SIGNING_ID'" "$ARCHIVE_PLIST"
fi

if [ -n "$TEAM_ID" ]; then
  /usr/libexec/PlistBuddy -c "Add :Team string '$TEAM_ID'" "$ARCHIVE_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :Team '$TEAM_ID'" "$ARCHIVE_PLIST"
fi

echo "✅ Archive fixed successfully!"

