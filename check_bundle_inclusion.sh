#!/bin/bash
echo "=== StoreKit Bundle Inclusion Check ==="
echo ""
echo "1. Is file in Resources build phase?"
if grep -A 10 "PBXResourcesBuildPhase" Habitto.xcodeproj/project.pbxproj | grep -q "HabittoSubscriptions.storekit"; then
    echo "   ⚠️  YES - File is in Resources build phase"
    echo "   NOTE: StoreKit config files should NOT be in Copy Bundle Resources"
    echo "   They should ONLY be referenced in the scheme!"
else
    echo "   ✅ NO - File is NOT in Resources (correct)"
fi
echo ""
echo "2. Scheme configuration:"
grep -A 2 "StoreKitConfigurationFileReference" Habitto.xcodeproj/xcshareddata/xcschemes/Habitto.xcscheme | grep "identifier"
echo ""
echo "3. File exists:"
ls -lh HabittoSubscriptions.storekit 2>/dev/null && echo "   ✅ File found" || echo "   ❌ File NOT found"
