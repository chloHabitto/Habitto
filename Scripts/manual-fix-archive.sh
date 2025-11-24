#!/bin/bash
# Manual script to fix the most recent archive
# Run this after archiving if the post-action doesn't work

LATEST_ARCHIVE=$(find ~/Library/Developer/Xcode/Archives -type d -name "*.xcarchive" -maxdepth 2 -mtime -1 | sort -r | head -1)

if [ -z "$LATEST_ARCHIVE" ]; then
    echo "❌ No recent archive found"
    exit 1
fi

echo "🔧 Fixing archive: $LATEST_ARCHIVE"
"$(dirname "$0")/fix-archive.sh" "$LATEST_ARCHIVE"

echo ""
echo "✅ Done! Check Organizer - the archive should now show as 'iOS App'"
echo "   If it still shows as 'Other Item', try:"
echo "   1. Close and reopen Xcode Organizer"
echo "   2. Or delete and re-archive"
