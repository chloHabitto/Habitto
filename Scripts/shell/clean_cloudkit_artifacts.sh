#!/bin/bash

# Clean CloudKit Artifacts Script
# This script removes all build artifacts and app data to fix CloudKit-related startup issues

set -e

echo "🧹 Starting cleanup of CloudKit artifacts..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean Derived Data
echo ""
echo "${YELLOW}Step 1: Cleaning DerivedData...${NC}"
DERIVED_DATA_PATH=~/Library/Developer/Xcode/DerivedData
if [ -d "$DERIVED_DATA_PATH" ]; then
    echo "Looking for Habitto-related derived data..."
    find "$DERIVED_DATA_PATH" -name "Habitto-*" -maxdepth 1 -exec rm -rf {} \; 2>/dev/null || true
    echo "${GREEN}✅ DerivedData cleaned${NC}"
else
    echo "No DerivedData directory found, skipping..."
fi

# Step 2: Remove app from booted simulator
echo ""
echo "${YELLOW}Step 2: Removing app from simulator...${NC}"
BUNDLE_ID="com.chloe.Habitto"

# Check if there's a booted simulator
if xcrun simctl list devices | grep -q "(Booted)"; then
    echo "Found booted simulator, removing app..."
    xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null || echo "App not installed or already removed"
    echo "${GREEN}✅ App removed from simulator${NC}"
else
    echo "No booted simulator found, skipping..."
fi

# Step 3: Clean build folder (requires manual action in Xcode)
echo ""
echo "${YELLOW}Step 3: Clean Build Folder${NC}"
echo "⚠️  Please manually run in Xcode: Product → Clean Build Folder (⌘+Shift+K)"

echo ""
echo "${GREEN}🎉 Cleanup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Clean Build Folder in Xcode (⌘+Shift+K)"
echo "2. Build and Run (⌘+R)"
echo ""
echo "Expected result:"
echo "✅ Fast startup (< 2 seconds)"
echo "✅ No CloudKit validation errors"
echo "✅ Clean console logs"

