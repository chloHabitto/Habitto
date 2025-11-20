#!/bin/bash
echo "=========================================="
echo "StoreKit Configuration Diagnostic Report"
echo "=========================================="
echo ""
echo "1. FILE EXISTENCE:"
if [ -f "HabittoSubscriptions.storekit" ]; then
    echo "   ✅ File exists"
    ls -lh HabittoSubscriptions.storekit
else
    echo "   ❌ File NOT found"
fi
echo ""
echo "2. PROJECT FILE:"
if grep -q "HabittoSubscriptions.storekit" Habitto.xcodeproj/project.pbxproj; then
    echo "   ✅ Found in project.pbxproj"
    echo "   File type:"
    grep "HabittoSubscriptions.storekit" Habitto.xcodeproj/project.pbxproj | grep "lastKnownFileType"
else
    echo "   ❌ NOT in project.pbxproj"
fi
echo ""
echo "3. RESOURCES BUILD PHASE:"
if grep -A 5 "PBXResourcesBuildPhase" Habitto.xcodeproj/project.pbxproj | grep -q "HabittoSubscriptions.storekit"; then
    echo "   ✅ In Resources build phase"
else
    echo "   ❌ NOT in Resources build phase"
fi
echo ""
echo "4. SCHEME CONFIGURATION:"
SCHEME_FILE="Habitto.xcodeproj/xcshareddata/xcschemes/Habitto.xcscheme"
if grep -q "StoreKitConfigurationFileReference" "$SCHEME_FILE"; then
    echo "   ✅ StoreKit configuration found in scheme"
    echo "   Path:"
    grep -A 1 "StoreKitConfigurationFileReference" "$SCHEME_FILE" | grep "identifier"
else
    echo "   ❌ StoreKit configuration NOT in scheme"
fi
echo ""
echo "5. PRODUCT IDS:"
echo "   In .storekit file:"
grep "productID" HabittoSubscriptions.storekit | sed 's/.*"productID" : "\(.*\)".*/      - \1/'
echo "   In Swift code:"
grep -A 3 "enum ProductID" Core/Managers/SubscriptionManager.swift | grep "static let" | sed 's/.*= "\(.*\)".*/      - \1/'
echo ""
echo "6. FILE TYPE:"
file HabittoSubscriptions.storekit
echo ""
echo "=========================================="
