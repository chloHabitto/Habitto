#!/bin/bash
echo "=== StoreKit Diagnostic Check ==="
echo ""
echo "1. File exists:"
ls -la HabittoSubscriptions.storekit 2>/dev/null && echo "✅ File found" || echo "❌ File NOT found"
echo ""
echo "2. File in project.pbxproj:"
grep -q "HabittoSubscriptions.storekit" Habitto.xcodeproj/project.pbxproj && echo "✅ Found in project.pbxproj" || echo "❌ NOT in project.pbxproj"
echo ""
echo "3. File in Resources build phase:"
grep -A 3 "PBXResourcesBuildPhase" Habitto.xcodeproj/project.pbxproj | grep -q "HabittoSubscriptions.storekit" && echo "✅ In Resources build phase" || echo "❌ NOT in Resources build phase"
echo ""
echo "4. Scheme configuration:"
grep -A 2 "StoreKitConfigurationFileReference" Habitto.xcodeproj/xcshareddata/xcschemes/Habitto.xcscheme
echo ""
echo "5. Product IDs in .storekit file:"
grep "productID" HabittoSubscriptions.storekit | sed 's/.*"productID" : "\(.*\)".*/\1/'
echo ""
echo "6. Product IDs in Swift code:"
grep -A 3 "enum ProductID" Core/Managers/SubscriptionManager.swift | grep "static let" | sed 's/.*= "\(.*\)".*/\1/'
echo ""
echo "7. iOS Deployment Target:"
grep "IPHONEOS_DEPLOYMENT_TARGET" Habitto.xcodeproj/project.pbxproj | head -1
