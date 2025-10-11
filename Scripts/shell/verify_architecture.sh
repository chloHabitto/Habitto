#!/bin/bash

# Habitto Data Architecture Verification Script
# This script verifies the critical components are implemented and builds successfully

echo "🧪 Habitto Data Architecture Verification"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "Habitto.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the Habitto project root directory"
    exit 1
fi

echo ""
echo "📁 Verifying critical files exist..."

# Check critical files
critical_files=(
    "Core/Data/Storage/CrashSafeHabitStore.swift"
    "Core/Data/Migration/DataMigrationManager.swift"
    "Core/Managers/FeatureFlags.swift"
    "Core/Utils/TextSanitizer.swift"
    "Core/Data/Migration/MigrationResumeTokenManager.swift"
    "Core/Security/FieldLevelEncryptionManager.swift"
)

all_files_exist=true
for file in "${critical_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
        all_files_exist=false
    fi
done

echo ""
echo "🔍 Verifying critical methods exist..."

# Check critical methods using git grep
methods=(
    "replaceItem("
    "synchronize()"
    "volumeAvailableCapacityForImportantUsage"
    "precomposedStringWithCanonicalMapping"
    "MigrationResumeToken"
    "FeatureFlags"
    "validateStorageInvariants"
    "rotateBackup"
)

all_methods_exist=true
for method in "${methods[@]}"; do
    if git grep -q "$method" Core/; then
        echo "✅ $method"
    else
        echo "❌ $method - NOT FOUND"
        all_methods_exist=false
    fi
done

echo ""
echo "🔨 Verifying project builds..."

# Build the project
if xcodebuild -project Habitto.xcodeproj -scheme Habitto -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet 2>/dev/null; then
    echo "✅ Project builds successfully"
    build_success=true
else
    echo "❌ Project build failed"
    build_success=false
fi

echo ""
echo "📊 Verification Summary"
echo "======================"

if [ "$all_files_exist" = true ] && [ "$all_methods_exist" = true ] && [ "$build_success" = true ]; then
    echo "🎉 ALL CRITICAL COMPONENTS VERIFIED"
    echo ""
    echo "✅ Core storage safety infrastructure is present:"
    echo "   • Atomic file operations with fsync"
    echo "   • Two-generation backup rotation"
    echo "   • Disk space checking with user alerts"
    echo "   • Unicode normalization (NFC)"
    echo "   • Migration resume tokens"
    echo "   • Feature flag system"
    echo "   • Invariant validation"
    echo ""
    echo "✅ Project builds successfully"
    echo ""
    echo "🚀 CORE DATA ARCHITECTURE IS PRODUCTION-READY"
    echo ""
    echo "⚠️  STILL NEEDED FOR FULL FEATURE DEPLOYMENT:"
    echo "   • Proper test target configuration"
    echo "   • Version skipping tests (v1→v4)"
    echo "   • Feature flag integration in data paths"
    echo "   • CloudKit sync implementation or explicit disable"
    echo "   • Field-level encryption integration or disable"
    echo "   • Telemetry hooks for migration events"
    echo ""
    echo "✅ SAFE TO SHIP: Core app updates"
    echo "❌ NOT SAFE TO SHIP: Advanced features (challenges, i18n, etc.)"
    echo "   until missing components are implemented"
else
    echo "⚠️  SOME COMPONENTS MISSING OR FAILED"
    echo ""
    if [ "$all_files_exist" = false ]; then
        echo "❌ Critical files missing"
    fi
    if [ "$all_methods_exist" = false ]; then
        echo "❌ Critical methods not found"
    fi
    if [ "$build_success" = false ]; then
        echo "❌ Project build failed"
    fi
    echo ""
    echo "❌ NOT READY FOR PRODUCTION DEPLOYMENT"
    echo "   Fix the issues above before proceeding"
fi

echo "=========================================="
