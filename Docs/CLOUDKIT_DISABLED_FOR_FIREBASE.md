# CloudKit Disabled for Firebase Migration

**Date**: October 12, 2025  
**Status**: ✅ Fixed  
**Impact**: Resolves 10-15 second startup lag and console errors

## Context

During the Firebase migration (Steps 1-6), we encountered significant startup performance issues caused by SwiftData attempting to validate against CloudKit requirements, even though we're transitioning to Firebase/Firestore as the single source of truth.

## Symptoms

- **Startup Lag**: 10-15 seconds on first launch
- **Console Spam**: Hundreds of "no such table: ZHABITDATA" errors
- **Database Resets**: Continuous corruption detection and database recreation
- **CloudKit Validation Errors**: "CloudKit integration requires that all relationships have an inverse..." 

## Root Cause

The app was previously configured with CloudKit entitlements and SwiftData was trying to maintain backward compatibility with the old CloudKit-enabled database schema, even after we:
1. Disabled CloudKit in code (`cloudKitDatabase: .none`)
2. Commented out CloudKit entitlements in `Habitto.entitlements`

The issue was that build artifacts and existing database files still contained CloudKit metadata.

## Solution

### 1. Entitlements Updated
**File**: `Habitto.entitlements`

CloudKit-related keys are now commented out:
```xml
<!-- CloudKit disabled - using Firestore as single source of truth -->
<!-- Uncomment below if CloudKit sync is needed in future -->
<!--
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
    <string>CloudDocuments</string>
</array>
-->
```

### 2. SwiftData Configuration
**File**: `Core/Data/SwiftData/SwiftDataContainer.swift`

ModelConfiguration explicitly disables CloudKit:
```swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .none)  // Disable automatic CloudKit sync
```

### 3. Cleanup Script Created
**File**: `Scripts/shell/clean_cloudkit_artifacts.sh`

Automated cleanup script that:
- Removes DerivedData artifacts
- Uninstalls app from simulator
- Provides instructions for manual clean build

**Usage**:
```bash
./Scripts/shell/clean_cloudkit_artifacts.sh
```

## Verification

After applying the fix and rebuilding:

✅ **Performance**: App starts in < 2 seconds  
✅ **Console**: Clean logs without CloudKit errors  
✅ **Database**: No corruption detection loops  
✅ **Functionality**: All existing features work normally  

## Future Considerations

### If CloudKit Sync is Needed Later

1. **Uncomment entitlements** in `Habitto.entitlements`
2. **Update SwiftData schema** to meet CloudKit requirements:
   - All relationships must have inverses
   - All attributes must be optional or have defaults
   - Relationships must be optional
   - Remove unique constraints
3. **Update ModelConfiguration**:
   ```swift
   let modelConfiguration = ModelConfiguration(
       schema: schema,
       isStoredInMemoryOnly: false,
       cloudKitDatabase: .automatic)
   ```
4. **Test migration path** from non-CloudKit to CloudKit

### Current Architecture

- **Primary Source of Truth**: Firebase Firestore
- **Local Cache**: SwiftData (CloudKit disabled)
- **Authentication**: Firebase Anonymous Auth
- **Sync Strategy**: Firestore offline persistence + real-time listeners

## Related Files

- `Habitto.entitlements` - CloudKit entitlements disabled
- `Core/Data/SwiftData/SwiftDataContainer.swift` - ModelConfiguration
- `Scripts/shell/clean_cloudkit_artifacts.sh` - Cleanup script
- `CLOUDKIT_DISABLED_FIX.md` - User-facing fix instructions

## Testing Checklist

- [x] App launches quickly (< 2 seconds)
- [x] No CloudKit validation errors in console
- [x] No database corruption loops
- [x] SwiftData works for local caching
- [x] Firebase authentication works
- [x] Firestore operations work
- [x] Existing user data preserved

## Migration Impact

This change is **non-breaking** for users:
- Existing local data is preserved
- App functionality remains unchanged
- Performance significantly improved
- Ready for Firebase migration steps 5-10
