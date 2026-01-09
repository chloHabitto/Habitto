# Code Cleanup & Simplification Report

**Generated:** $(date)  
**Scope:** Full codebase analysis for dead code, unused files, and consolidation opportunities

---

## Executive Summary

**Estimated Impact:**
- **~3,500+ lines of code** can be safely removed
- **15-20 files** can be deleted entirely
- **8 CloudKit files** can be archived (disabled feature)
- **Multiple duplicate implementations** can be consolidated

**Risk Level:** Low to Medium (most items are clearly unused or disabled)

---

## 1. Dead Code & Unused Files

### Files Safe to Delete (High Confidence)

#### 1.1 `Core/Data/HabitRepositoryNew.swift` (252 lines)
**Status:** ❌ **UNUSED** - Can be deleted  
**Reasoning:**
- Only referenced in its own file (`static let shared = HabitRepositoryNew()`)
- No imports or usage found in codebase
- App uses `HabitRepository.swift` (1992 lines) as the primary repository
- `HabitRepositoryImpl.swift` is used by `StorageFactory` for protocol-based implementations

**Action:** Delete file entirely

---

#### 1.2 `Core/Data/CoreDataManager.swift` (163 lines)
**Status:** ⚠️ **STUB/DEAD CODE** - Can be deleted  
**Reasoning:**
- Running in "Simple Mode" with empty entities
- All methods return empty arrays or throw errors
- Comments indicate "bypassed - using UserDefaults instead"
- Only used for `dateKey(for:)` utility method (3 references)
- App uses SwiftData, not CoreData

**Action:** 
- Delete file
- Move `dateKey(for:)` utility to a shared utility file if still needed

**References to update:**
- `Core/Data/Repository/HabitStore.swift` (lines 504, 519, 722) - uses `CoreDataManager.dateKey(for:)`

---

#### 1.3 `Core/Data/OptimizedHabitStorageManager.swift` (337 lines)
**Status:** ⚠️ **LEGACY - Used in Migrations/Tests**  
**Reasoning:**
- Referenced in `Core/Models/Habit.swift` static methods (lines 367-377)
- Used by migration code (`CompletionStatusMigration.swift`)
- Used by test code (`MigrationTestRunner.swift`)
- Used by sample data generator (`SampleDataGenerator.swift`)
- Used by archive migration code (`Core/Migration/Archive/`)
- **NOT used in production code** - `HomeView.swift` has comment: "Use HabitRepository instead of direct Habit.loadHabits()"
- Current architecture uses `HabitStore` actor → `SwiftDataStorage` → SwiftData

**Action:** 
- **Keep for now** - Still needed for migrations and tests
- Consider refactoring migrations to use `HabitRepository` instead
- After migrations are complete, can be removed

---

### Files to Investigate Further

#### 1.4 `Core/Data/Protocols/DataStorageProtocol.swift`
**Status:** ⚠️ **MINIMALLY USED**  
**Reasoning:**
- Only used in `Core/Data/Storage/TransactionalStorage.swift` (line 324)
- Protocol defines generic storage interface but most code uses `HabitStorageProtocol` directly
- `HabitStorageProtocol` extends `DataStorageProtocol`, so it may still be needed

**Action:** Verify if `TransactionalStorage` is actually used

---

## 2. Disabled/Commented Code Paths

### 2.1 CloudKit Infrastructure (8 files) - **DISABLED**

**Status:** ❌ **COMPLETELY DISABLED** - Can be archived  
**Files:**
- `Core/Data/CloudKit/CloudKitConflictResolver.swift`
- `Core/Data/CloudKit/CloudKitIntegrationService.swift`
- `Core/Data/CloudKit/CloudKitModels.swift`
- `Core/Data/CloudKit/CloudKitSchema.swift`
- `Core/Data/CloudKit/CloudKitSyncManager.swift`
- `Core/Data/CloudKit/CloudKitTypes.swift`
- `Core/Data/CloudKit/CloudKitUniquenessManager.swift`
- `Core/Data/CloudKit/ConflictResolutionPolicy.swift`
- `Core/Data/CloudKitManager.swift` (main manager)

**Evidence:**
- `RemoteConfigService.shared.enableCloudKitSync = false` (hardcoded)
- `CloudKitManager.isCloudKitAvailable()` returns `false`
- `CloudKitSyncManager` logs "CloudKit disabled for now"
- All CloudKit sync calls are commented out or return early

**Action:** 
- **Option A:** Move entire `Core/Data/CloudKit/` folder to `Core/Data/CloudKit/Archive/`
- **Option B:** Delete if not planning to re-enable
- Keep `CloudKitManager.swift` if it has utility methods, but remove CloudKit-specific code

**Code References to Clean:**
- `Core/Data/HabitRepository.swift` (lines 1348, 1415-1426, 872-874) - CloudKit initialization
- `Core/Data/Repository/HabitRepositoryImpl.swift` (lines 12, 25, 272) - CloudKit manager references
- `Core/Data/Repository/HabitStore.swift` (lines 949-960, 1084-1086) - CloudKit sync methods

**Estimated LOC Reduction:** ~1,200 lines

---

### 2.2 CoreDataManager - Already Covered in Section 1.2

---

### 2.3 Commented-Out Code Blocks

**Large commented blocks found:**

1. **`Core/Data/HabitRepository.swift`** (lines 1384-1393)
   - Commented sync code: `// ✅ GUEST-ONLY MODE: Sync disabled`
   - Can be removed if sync is permanently disabled

2. **`Core/Data/HabitRepository.swift`** (lines 1667-1672, 1708-1709)
   - Commented `SyncEngine.shared` calls
   - Can be removed if sync is permanently disabled

3. **`Core/Data/HabitRepository.swift`** (lines 1818-1832)
   - Large commented function `resetUserDataToGuest()` with explanation
   - Can be removed if Option B (Account Data Isolation) is permanent

**Action:** Remove commented code blocks (keep if they're documentation/todos)

---

## 3. Duplicate/Overlapping Implementations

### 3.1 Repository Implementations

**Current State:**
- `Core/Data/HabitRepository.swift` (1992 lines) - **PRIMARY** ✅
- `Core/Data/HabitRepositoryNew.swift` (252 lines) - **UNUSED** ❌
- `Core/Data/Repository/HabitRepositoryImpl.swift` (328 lines) - **USED BY FACTORY** ✅
- `Core/Data/Repositories/HabitRepositoryProtocol.swift` (61 lines) - **PROTOCOL** ✅

**Analysis:**
- `HabitRepository` is the main repository used throughout the app
- `HabitRepositoryImpl` is used by `StorageFactory` for protocol-based storage switching
- `HabitRepositoryNew` is completely unused

**Action:**
- ✅ Keep `HabitRepository.swift` (primary)
- ✅ Keep `HabitRepositoryImpl.swift` (factory pattern)
- ❌ Delete `HabitRepositoryNew.swift` (unused)

---

### 3.2 Storage Implementations

**Current State:**
- `Core/Data/SwiftData/SwiftDataStorage.swift` - **PRIMARY** ✅
- `Core/Data/OptimizedHabitStorageManager.swift` - **LEGACY** ⚠️
- `Core/Data/Storage/UserDefaultsStorage.swift` - **FALLBACK** ✅

**Analysis:**
- SwiftData is primary storage
- UserDefaultsStorage is fallback (used by `UserAwareStorage`)
- OptimizedHabitStorageManager appears to be legacy

**Action:**
- Verify `OptimizedHabitStorageManager` usage
- If unused, delete and remove `Habit.swift` extension methods

---

### 3.3 Migration Services

**Current State:**
- `Core/Data/Migration/DataMigrationManager.swift` - **ACTIVE** ✅
- `Core/Services/MigrationService.swift` - **WRAPPER** ✅
- `Core/Services/MigrationRunner.swift` - **SWIFTDATA MIGRATIONS** ✅

**Analysis:**
- `DataMigrationManager` handles legacy UserDefaults → SwiftData migrations
- `MigrationService` is a wrapper around `DataMigrationManager`
- `MigrationRunner` handles SwiftData schema migrations

**Action:**
- ✅ Keep all three (different purposes)
- Consider renaming for clarity if needed

---

### 3.4 RepositoryProvider System

**Current State:**
- `Core/Data/RepositoryProvider.swift` - **INCOMPLETE** ⚠️
- `Core/Data/Repositories/RepositoryFacade.swift` - **ACTIVE** ✅

**Analysis:**
- `RepositoryProvider` is used by `AuthRoutingManager` but implementations are incomplete
- `NormalizedHabitRepository` and `LegacyHabitRepository` have many `TODO` comments
- Methods throw "Method not implemented" errors
- App currently uses `HabitRepository.shared` directly, not through `RepositoryProvider`

**Action:**
- ⚠️ **Investigate** - Is this a work-in-progress feature flag system?
- If not being used, can be removed or marked as experimental
- If being developed, complete implementations or remove

---

## 4. Migration System Bloat

### 4.1 Migration Files Analysis

**Location:** `Core/Data/Migration/` (14 files)

**Active Migrations (Keep):**
- ✅ `GuestDataMigration.swift` - Active (guest → authenticated user)
- ✅ `GuestDataMigrationHelper.swift` - Active helper
- ✅ `GuestToAuthMigration.swift` - Active (SwiftData migration)
- ✅ `MigrationStateStore.swift` - Active (tracks migration state)
- ✅ `XPMigrationService.swift` - Active (XP data migration)
- ✅ `CompletionStatusMigration.swift` - Active (completion status migration)
- ✅ `MigrateCompletionsToEvents.swift` - Active (event sourcing migration)

**Legacy/Completed Migrations (Can Archive):**
- ⚠️ `DataFormatMigrations.swift` - Contains legacy format migrations
  - `AddHabitCreationDateMigration` - Likely completed for all users
  - `NormalizeHabitGoalMigration` - Likely completed
  - `CleanUpInvalidDataMigration` - May still be needed
- ⚠️ `StorageMigrations.swift` - Contains `UserDefaultsToCoreDataMigration` (disabled, CoreData not used)
- ⚠️ `BackfillJob.swift` - Backfill operations (check if still needed)
- ⚠️ `DataMigrationManager.swift` - Has comments indicating migrations are complete:
  - Line 319: "NOTE: App has migrated to SwiftData, CrashSafeHabitStore is legacy"
  - Line 331: "NOTE: App has migrated to SwiftData, snapshots are no longer needed"
  - Line 350: "NOTE: App has migrated to SwiftData, all migrations are considered complete"

**Utility Files (Keep):**
- ✅ `MigrationInvariantsValidator.swift` - Validation utility
- ✅ `MigrationResumeTokenManager.swift` - Resume token management
- ✅ `MigrationVerificationHelper.swift` - Verification utility

**Action:**
1. Review `DataMigrationManager.setupMigrationSteps()` (line 368) - only 4 migrations active
2. Archive completed migrations to `Core/Data/Migration/Archive/`
3. Remove `UserDefaultsToCoreDataMigration` from `StorageMigrations.swift` (CoreData disabled)

**Estimated LOC Reduction:** ~400-600 lines (archived migrations)

---

## 5. Debug/Development Code in Production

### 5.1 Debug Views

**Location:** `Views/Debug/` (5 files)

**Status:** ✅ **PROPERLY GUARDED**  
**Analysis:**
- All debug views are wrapped in `#if DEBUG` blocks
- Accessible via hidden gesture (5 taps) in `MoreTabView`
- Not accessible in production builds

**Files:**
- `DailyAwardIntegrityView.swift` - Debug tool
- `FeatureFlagsDebugView.swift` - Feature flag debugging
- `HabitInvestigationView.swift` - Habit diagnostics
- `MigrationDebugView.swift` - Migration testing
- `MigrationStatusDebugView.swift` - Migration status
- `SyncHealthView.swift` - Sync health monitoring

**Action:** ✅ **KEEP** - Properly guarded, useful for debugging

---

### 5.2 Debug Utilities

**Location:** `Core/Debug/HabitInvestigator.swift`

**Status:** ✅ **USED BY DEBUG VIEWS**  
**Action:** ✅ **KEEP**

---

### 5.3 Print/Debug Statements

**Status:** ⚠️ **MIXED**  
**Analysis:**
- Many `print()` statements throughout codebase
- Some use `debugLog()` utility (better)
- Production builds should use proper logging

**Action:**
- Replace `print()` with `debugLog()` or proper logging framework
- Use `#if DEBUG` for verbose debug prints
- Keep error logging in production

**Files with excessive prints:**
- `Core/Data/HabitRepository.swift` - Many debug prints
- `Core/Data/CoreDataManager.swift` - All prints (file can be deleted)
- `Core/Analytics/UserAnalytics.swift` - Many prints

---

## 6. Unused Dependencies & Imports

### 6.1 CloudKit Imports

**Files with unused CloudKit imports:**
- `Core/Data/CoreDataManager.swift` - `import CloudKit` (file can be deleted)
- `Core/Data/GDPRDataDeletionManager.swift` - Uses `MockCloudKitManager` (may be needed)
- `Core/Managers/ICloudStatusManager.swift` - `import CloudKit` (check if used)

**Action:**
- Remove CloudKit imports from files that don't use CloudKit
- After archiving CloudKit folder, remove all CloudKit imports

---

### 6.2 CoreData Imports

**Files with CoreData imports:**
- `Core/Data/HabitRepository.swift` - `import CoreData` (lines 2, 20-63 define CoreData entities)
- `Core/Data/CoreDataManager.swift` - `import CoreData` (file can be deleted)

**Analysis:**
- `HabitRepository.swift` defines CoreData entity stubs (`HabitEntity`, etc.)
- These are marked as "temporary stubs until the Core Data model is restored"
- Since CoreData is disabled, these stubs may be removable

**Action:**
- Remove CoreData entity stubs from `HabitRepository.swift` (lines 16-128)
- Remove `import CoreData` if no longer needed

---

## 7. Consolidation Opportunities

### 7.1 Small Extension Files

**Check for consolidation:**
- `Core/Extensions/` - 3 files (check if small enough to merge)
- Small utility files that could be grouped

**Action:** Review file sizes and logical grouping

---

### 7.2 Manager Classes with Little Code

**Files to review:**
- `Core/Managers/` - 16 files (check for small managers that could be merged)

**Action:** Identify managers < 100 lines that could be consolidated

---

### 7.3 Similar Utility Functions

**Potential consolidation:**
- Date formatting utilities (may be scattered)
- String utilities
- Validation helpers

**Action:** Audit utility functions for duplication

---

## 8. UI Components Cleanup

### 8.1 Unused UI Components

**Action:** 
- Search for components in `Core/UI/` that aren't imported anywhere
- Check `Views/` for duplicate styling code

**Note:** This requires deeper analysis of view imports

---

## Summary of Recommended Actions

### Immediate (High Confidence, Low Risk)

1. ✅ **Delete `HabitRepositoryNew.swift`** (252 lines)
2. ✅ **Delete `CoreDataManager.swift`** (163 lines) - Move `dateKey()` utility first
3. ✅ **Archive CloudKit folder** (8 files, ~1,200 lines)
4. ✅ **Remove CoreData entity stubs** from `HabitRepository.swift` (~110 lines)
5. ✅ **Remove commented sync code** blocks (~50 lines)

**Total Immediate Reduction:** ~1,775 lines

---

### Medium Priority (Verify First)

1. ⚠️ **Delete `OptimizedHabitStorageManager.swift`** (337 lines) - Verify `Habit.swift` extension usage
2. ⚠️ **Archive completed migrations** (~400-600 lines)
3. ⚠️ **Remove CloudKit imports** from non-CloudKit files
4. ⚠️ **Replace `print()` with proper logging**

**Total Medium Priority Reduction:** ~800-1,000 lines

---

### Low Priority (Investigation Needed)

1. 🔍 **Consolidate small utility files**
2. 🔍 **Audit UI components for unused code**
3. 🔍 **Review manager classes for consolidation**

---

## Estimated Total Impact

- **Lines of Code Reduction:** ~2,500-3,500 lines
- **Files Deleted:** 10-15 files
- **Files Archived:** 8-10 files
- **Complexity Reduction:** Significant (removes dead code paths, simplifies architecture)

---

## Risk Assessment

**Low Risk:**
- Deleting `HabitRepositoryNew.swift` (unused)
- Archiving CloudKit (disabled)
- Removing CoreData stubs (CoreData disabled)

**Medium Risk:**
- Deleting `OptimizedHabitStorageManager` (verify usage first)
- Archiving migrations (ensure all users migrated)

**High Risk:**
- None identified in this analysis

---

## Next Steps

1. **Phase 1 (Immediate):** Delete unused files (HabitRepositoryNew, CoreDataManager)
2. **Phase 2 (Week 1):** Archive CloudKit, remove CoreData stubs
3. **Phase 3 (Week 2):** Verify and archive completed migrations
4. **Phase 4 (Week 3):** Replace print statements, clean imports
5. **Phase 5 (Ongoing):** Consolidate utilities, audit UI components

---

## Notes

- All deletions should be done in separate commits for easy rollback
- Test thoroughly after each phase
- Keep archived code in version control for reference
- Update documentation after cleanup
