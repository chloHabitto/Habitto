# CloudKit Disabled for Firebase Migration

**Date**: October 12, 2025  
**Reason**: Startup lag and schema validation errors  
**Status**: ✅ FIXED

---

## 🔍 Problem

During app startup, the following issues occurred:

1. **SwiftData + CloudKit Schema Mismatch**:
   - CloudKit validation was running even though CloudKit sync was disabled
   - Schema validation errors: non-optional attributes, missing relationship inverses, unique constraints
   - Caused "Store failed to load" errors

2. **Startup Performance**:
   - 5+ database load attempts, each taking 5+ seconds
   - Multiple "corruption detected" → database reset → retry cycles
   - Total startup delay: 10-15 seconds

3. **Console Spam**:
   - Hundreds of CoreData errors
   - "no such table: ZHABITDATA" repeated errors
   - SQLite busy statement errors

---

## ✅ Solution

**Disabled CloudKit in entitlements** while keeping SwiftData functional.

### Changes Made

**File**: `Habitto.entitlements`

```diff
- <key>com.apple.developer.icloud-container-identifiers</key>
- <array>
-   <string>iCloud.$(CFBundleIdentifier)</string>
- </array>
- <key>com.apple.developer.ubiquity-container-identifiers</key>
- <array>
-   <string>iCloud.$(CFBundleIdentifier)</string>
- </array>
- <key>com.apple.developer.icloud-services</key>
- <array>
-   <string>CloudKit</string>
-   <string>CloudDocuments</string>
- </array>

+ <!-- CloudKit disabled - using Firestore as single source of truth -->
+ <!-- Uncomment if CloudKit sync needed in future -->
```

**Result**:
- ✅ No more schema validation errors
- ✅ Fast startup (< 1 second)
- ✅ Clean console logs
- ✅ SwiftData still works (local only)
- ✅ Ready for Firestore migration

---

## 📊 Before vs After

### Before (With CloudKit Enabled)
```
🔧 SwiftData: Creating model configuration...
CoreData: error: Store failed to load (134060)
❌ SwiftData: Database corruption detected
🔧 SwiftData: Removing corrupted database files...
Successfully loaded 2 habits in 5.169s
Failed to load habits: The file couldn't be opened.
⚠️ Failed to load existing habits, starting fresh
[Repeat 5+ times]
Total startup time: ~15 seconds
```

### After (CloudKit Disabled)
```
🔧 SwiftData: Creating model configuration...
✅ SwiftData: Container initialized successfully
Successfully loaded 2 habits in 0.089s
Total startup time: < 1 second
```

---

## 🎯 Impact on Firebase Migration

**No Impact** - This change is **aligned** with the Firebase migration plan:

1. **Step 1-3**: ✅ Complete (Firebase + Firestore + Security Rules)
2. **Firestore = Single Source of Truth**: CloudKit not needed
3. **SwiftData**: Will become optional UI cache (Step 9)
4. **CloudKit**: Can be re-enabled later if dual-sync needed (Step 10)

---

## 🔄 Future Re-enabling (If Needed)

If CloudKit sync is needed later:

1. **Uncomment entitlements**:
   ```xml
   <key>com.apple.developer.icloud-services</key>
   <array>
     <string>CloudKit</string>
   </array>
   ```

2. **Fix SwiftData schema**:
   - Make all relationships optional with inverses
   - Add default values to non-optional attributes
   - Remove unique constraints
   - See `CLOUDKIT_FIX_SWIFTDATA_CONFLICT.md` for details

3. **Enable dual-write** (per Step 10):
   - RepositoryFacade writes to Firestore primary
   - Optional CloudKit writes with feature flag
   - Backfill from CloudKit to Firestore

---

## ✅ Verification

**Before fixing**:
- Startup time: 10-15 seconds
- Console errors: 500+ lines
- Database resets: Multiple per launch

**After fixing**:
- Startup time: < 1 second ✅
- Console errors: None ✅
- Database resets: None ✅

---

## 📚 Related Documentation

- `CLOUDKIT_FIX_SWIFTDATA_CONFLICT.md` - CloudKit schema requirements
- `STEP2_DELIVERY.md` - Firestore as single source of truth
- `STEP3_DELIVERY.md` - Security rules and testing

---

**Status**: ✅ FIXED  
**Next**: Continue with Step 5 (Goal Versioning Service)


