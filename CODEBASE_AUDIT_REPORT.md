# Habitto Codebase Audit Report
Generated: January 18, 2026

---

## Executive Summary

This comprehensive audit examined the Habitto codebase for:
- **Redundant code**: Duplicate functions, logic, and patterns
- **Performance issues**: Memory leaks, main thread blocking, N+1 queries
- **Architecture complexity**: Unnecessary layers and abstractions
- **Safety gaps**: Error handling, data integrity, race conditions
- **Dead code**: Unused imports, deprecated features, Archive folders
- **Technical debt**: TODOs, feature flags, migration artifacts

### Key Metrics
- **Total Swift files**: ~340 files
- **print() statements in Core/**: 2,421 instances across 113 files
- **Force unwraps (!)**: 995 instances across 187 files
- **try? (silent errors)**: 266 instances across 68 files
- **try! (crash risks)**: 1 instance
- **.shared singletons**: 101 singleton instances
- **TODO/FIXME/HACK comments**: 120+ instances
- **DateFormatter creations**: 293 instances (many not cached)
- **@Published properties**: 233 instances
- **CloudKit imports**: 10 files (CloudKit is disabled!)
- **Archive folders**: 28 archived files still in codebase

---

## 📁 1. Redundant Code Detection

### 1.1 Duplicate Streak Calculation Functions ⚠️ **CRITICAL**

**Problem**: Multiple implementations of streak calculation logic exist across the codebase.

#### Found Implementations:

1. **`StreakCalculator.swift`** (Core/Streaks/) - **AUTHORITATIVE**
   - `computeCurrentStreak()` - Modern, well-documented
   - `computeLongestStreakFromHistory()` - Complete implementation
   - Uses `CompletionMode.current` for flexible streak modes
   - Has proper SHA256 checksum for data drift detection

2. **`StreakDataCalculator.swift`** (Core/Data/) - **LEGACY**
   - `calculateBestStreakFromHistory()` - Older implementation
   - `calculateStreakStatistics()` - Wrapper around multiple calculations
   - `calculateOverallStreakWhenAllCompleted()` - Private helper
   - **Issue**: Tries to access `HabitData` with `MainActor.assumeIsolated` which is hacky

3. **Individual Habit Methods** (Core/Models/Habit.swift)
   - `calculateTrueStreak()` - Instance method on Habit
   - `validateStreak()` - Validation logic
   - `correctStreak()` - Correction logic
   - **Issue**: Duplicates logic from StreakCalculator

4. **View-Level Calculations** (Views/)
   - `ProgressTabView.updateStreakStatistics()` - Line 1880
   - `HomeView.updateStreak()` - Line 134
   - `HomeView.updateAllStreaks()` - Line 577
   - `calculateHabitBestStreak()` in CalendarGridViews - Multiple instances

5. **Archive/Legacy Services**
   - `Core/Services/Archive/StreakService.swift` - Old service pattern
   - `Core/Migration/Archive/StreakMigrator.swift` - Migration-specific

**Recommendation**:
```
✅ KEEP: StreakCalculator.swift as single source of truth
❌ CONSOLIDATE: Move StreakDataCalculator methods to StreakCalculator
❌ REMOVE: Habit instance methods - delegate to StreakCalculator
❌ REFACTOR: View-level calculations should call StreakCalculator
❌ ARCHIVE: Delete Archive/StreakService.swift and StreakMigrator.swift
```

---

### 1.2 Duplicate Filtering by userId

**Filtering logic is duplicated across 8 files:**

Locations with `filter.*userId`:
1. `Core/Data/SwiftData/SwiftDataStorage.swift` - 1 instance
2. `Core/Data/HabitRepository.swift` - 5 instances
3. `Core/Data/Repository/HabitStore.swift` - 1 instance
4. `Core/Services/DailyAwardService.swift` - 3 instances
5. `Core/Managers/XPManager.swift` - 2 instances
6. `App/HabittoApp.swift` - 22 instances (!!)
7. `Core/Services/DataRepairService.swift` - 5 instances
8. `Core/Data/Migration/GuestDataMigrationHelper.swift` - 3 instances

**Recommendation**: Create a centralized filtering utility:
```swift
// Core/Utils/UserFiltering.swift
enum UserFiltering {
    static func filterHabits(_ habits: [Habit], for userId: String) -> [Habit] {
        habits.filter { $0.userId == userId }
    }
    
    static func filterRecords<T: HasUserId>(_ records: [T], for userId: String) -> [T] {
        records.filter { $0.userId == userId }
    }
}
```

---

### 1.3 DateFormatter Redundancy ⚠️ **PERFORMANCE IMPACT**

**Problem**: DateFormatter is created 293 times across 88 files. Creating DateFormatter is expensive!

**Heavy users:**
- `Core/Utils/Design/DatePreferences.swift` - 16 instances
- `Core/Data/CalendarGridViews.swift` - 29 instances
- `Views/Tabs/ProgressTabView.swift` - 30 instances
- `Core/UI/Components/ExpandableCalendar.swift` - 17 instances

**Current partial solution exists:**
- `Core/Utils/Design/DatePreferences.swift` has `AppDateFormatter.shared` (static cached)
- `Core/Time/LocalDateFormatter.swift` - 6 instances (some cached)
- `Core/Utils/Date/ISO8601DateHelper.swift` - Has `.shared` singleton with cached formatters

**Recommendation**:
```swift
✅ CONSOLIDATE: Use ISO8601DateHelper.shared and AppDateFormatter.shared everywhere
❌ REMOVE: All ad-hoc DateFormatter() creations
✅ ADD: Cached formatters for common patterns (yyyy-MM-dd, etc.)
```

---

### 1.4 Duplicate modelContext.save() Calls

**Found 91 `modelContext.save()` calls across 23 files.**

**Potential issues:**
- Multiple saves in quick succession
- Saves inside loops (batching opportunity)
- No transaction batching

**Files with multiple saves:**
- `Core/Data/SwiftData/SwiftDataStorage.swift` - 14 saves
- `Core/Data/Sync/SyncEngine.swift` - 11 saves
- `Core/Services/Archive/XPService.swift` - 6 saves
- `Core/Services/Archive/HabitService.swift` - 8 saves

**Recommendation**:
```
✅ BATCH: Group related saves into single transaction
✅ DEBOUNCE: Use 100ms debounce for rapid UI updates
❌ REMOVE: Redundant saves (SwiftData auto-saves on changes)
```

---

### 1.5 Completion Checking Logic Duplication

**Found 132 instances of completion checking across 30 files:**

Key methods:
- `habit.isCompleted(for: date)` - Used everywhere
- `habit.meetsStreakCriteria(for: date)` - Streak-specific logic
- `habit.getProgress(for: date)` - Progress calculation
- Direct `completionHistory[dateKey]` access

**Duplication in:**
- `StreakCalculator` - Line 72, 155, 190
- `StreakDataCalculator` - Lines 59, 112, 239
- `CalendarGridViews` - 14 instances
- `HabitDataModel` - Multiple methods

**Recommendation**:
```
✅ STANDARDIZE: Use habit.isCompleted(for:) for binary checks
✅ STANDARDIZE: Use habit.meetsStreakCriteria(for:) for streak logic
❌ AVOID: Direct completionHistory dictionary access
✅ CENTRALIZE: Completion percentage logic in one place
```

---

### 1.6 Dead Code: DEPRECATED/LEGACY Comments

**Search for comments referencing old work:**
- No active DEPRECATED or LEGACY comments found
- Good! Previous cleanup was effective

**However, found:**
- `// TODO:` comments throughout (120+ instances)
- `// FIXME:` comments
- `// HACK:` comments

**Recommendation**: Review all TODO/FIXME/HACK comments:
```bash
# Priority todos that may be outdated:
grep -r "TODO: Remove after" Core/
```

---

### 1.7 Unused Imports ⚠️ **CLEANUP NEEDED**

**CloudKit Imports (CloudKit is disabled!):**
```
./Core/Data/CloudKit/Archive/ConflictResolutionPolicy.swift
./Core/Data/CloudKit/Archive/CloudKitTypes.swift
./Core/Data/CloudKit/Archive/CloudKitSyncManager.swift
./Core/Data/CloudKit/Archive/CloudKitSchema.swift
./Core/Data/CloudKit/Archive/CloudKitModels.swift
./Core/Data/CloudKit/Archive/CloudKitIntegrationService.swift
./Core/Data/CloudKit/Archive/CloudKitConflictResolver.swift
./Core/Managers/ICloudStatusManager.swift (still active!)
./Core/Data/GDPRDataDeletionManager.swift (has mock CloudKit)
./Core/Data/CloudKitManager.swift (still active!)
```

**Recommendation**:
```
❌ DELETE: Entire Core/Data/CloudKit/Archive/ folder (8 files)
⚠️  REVIEW: ICloudStatusManager - is this still needed?
⚠️  REVIEW: CloudKitManager - appears to be disabled but not deleted
```

**CoreData Imports:**
- No CoreData imports found ✅ (good - migrated to SwiftData)

---

### 1.8 Archive Folders Still in Codebase ⚠️ **MAJOR CLEANUP**

**28 archived files found:**

```
Core/Utils/Archive/
  - DateKey.swift
  - EventSourcedUtils.swift

Core/Data/CloudKit/Archive/ (8 files)
  - All CloudKit integration code

Core/Models/Archive/New/ (8 files)
  - GlobalStreakModel.swift
  - HabitSchedule.swift
  - DailyProgressModel.swift
  - UserProgressModel.swift
  - XPTransactionModel.swift
  - AchievementModel.swift
  - HabitModel.swift
  - ReminderModel.swift

Core/Services/Archive/ (4 files)
  - StreakService.swift
  - ServiceContainer.swift
  - XPService.swift
  - HabitService.swift
  - ProgressService.swift

Core/Migration/Archive/ (6 files)
  - MigrationValidator.swift
  - XPMigrator.swift
  - StreakMigrator.swift
  - MigrationManager.swift
  - HabitMigrator.swift
```

**Recommendation**:
```
❌ DELETE ALL: Move to git history if needed for reference
⚠️  EXCEPTION: Check if Archive/New models are still referenced
✅ BENEFIT: Remove ~3000+ lines of dead code
```

---

## ⚡ 2. Performance Optimization

### 2.1 Main Thread Safety Analysis

**@MainActor usage: 312 instances across 113 files**

**Good practices found:**
- `SwiftDataStorage` is `@MainActor` ✅
- `HabitRepository` is `@MainActor` ✅
- View models properly isolated

**Potential issues:**
- `HabitStore` is an actor (good!) but has 1529 lines
- Heavy operations in SwiftDataStorage (should delegate to background)
- `modelContext.save()` always on main thread

**Specific concerns:**

1. **SwiftDataStorage.loadHabits()** (Line 368-500)
   - Fetches all habits on main thread
   - Filters completion records synchronously
   - No pagination for large datasets

2. **StreakDataCalculator** methods
   - `calculateBestStreakFromHistory()` uses `MainActor.assumeIsolated` (Line 32)
   - Synchronous calculations that could be async

**Recommendation**:
```swift
✅ MOVE: Heavy calculations to background actors
✅ USE: Task.detached for expensive operations
✅ PAGINATE: Large dataset loads
❌ AVOID: MainActor.assumeIsolated (use proper async/await)
```

---

### 2.2 Memory & Strong Reference Cycles

**[weak self] usage: 45 instances across 23 files**

**Good**: Most closures properly use `[weak self]`

**Potential leaks found:**
- `Core/Data/BackgroundQueueManager.swift` - 7 closures (check if all use weak)
- `Core/Services/EventCompactor.swift` - 9 Logger references (static, OK)
- View `.task` modifiers - many don't need weak self (OK in SwiftUI)

**@Published properties: 233 instances across 62 files**

**Heavy publishers:**
- `Core/Data/HabitRepository.swift` - 10+ @Published properties
- `Core/Managers/SubscriptionManager.swift` - 3+ @Published
- View models have appropriate usage

**Potential issue**: Publishing inside loops
```swift
// Example of bad pattern:
for habit in habits {
    self.currentHabit = habit // Triggers @Published update N times
}
```

**Recommendation**:
```
✅ AUDIT: Check all @Published updates in loops
✅ BATCH: Collect results, then publish once
✅ USE: @Published only for UI-bound state
```

---

### 2.3 Query Optimization

**FetchDescriptor usage: 264 instances across 51 files**

**Heavy users:**
- `Core/Data/Sync/SyncEngine.swift` - 19 descriptors
- `Core/Data/SwiftData/SwiftDataStorage.swift` - 22 descriptors
- `Core/Data/SwiftData/SwiftDataContainer.swift` - 21 descriptors

**Potential N+1 query problems:**

Example from code inspection:
```swift
// Load habits
let habits = try await loadHabits()

// Then for each habit, load related data (N queries!)
for habit in habits {
    let records = try await loadCompletionRecords(for: habit.id)
}
```

**Found in:**
- Completion record loading (per-habit queries)
- XP calculation (loads awards per habit)
- Progress calculations

**Recommendation**:
```swift
// BEFORE (N+1):
for habit in habits {
    let completions = loadCompletions(for: habit.id)
}

// AFTER (1 query):
let allCompletions = loadCompletions(for: habitIds)
let completionsByHabit = Dictionary(grouping: allCompletions) { $0.habitId }
```

---

## 🏗️ 3. Architecture Simplification

### 3.1 Layer Redundancy Analysis ⚠️ **HIGH PRIORITY**

**Current architecture has 3 data layers:**

```
UI/Views
    ↓
HabitRepository (@MainActor facade)
    ↓
HabitStore (actor for thread safety)
    ↓
SwiftDataStorage (@MainActor storage)
    ↓
SwiftData ModelContext
```

**Analysis:**

1. **HabitRepository** (Core/Data/HabitRepository.swift)
   - 1,843 lines
   - Role: @MainActor facade, publishes to UI
   - Has: User auth monitoring, CloudKit init, sync status
   - **Value**: Provides ObservableObject for SwiftUI

2. **HabitStore** (Core/Data/Repository/HabitStore.swift)
   - 1,529 lines
   - Role: Actor for thread-safe operations
   - Has: CRUD operations, validation, migration checks
   - **Value**: Thread safety via actor isolation

3. **SwiftDataStorage** (Core/Data/SwiftData/SwiftDataStorage.swift)
   - 1,286 lines
   - Role: Direct SwiftData operations
   - Has: ModelContext operations, HabitData ↔ Habit conversion
   - **Value**: Abstracts SwiftData specifics

**Problems:**
- Data passes through 3 layers for simple operations
- Duplication: All three handle errors, logging, userId filtering
- Confusion: Unclear when to call Repository vs Store vs Storage
- Testing: Have to mock 3 layers

**Recommendation**:
```
OPTION A - Simplify to 2 layers:
  UI → HabitRepository (@MainActor) → SwiftData
  
OPTION B - Keep 3 but clarify:
  - Repository: UI state + coordination
  - Store: Business logic + validation
  - Storage: Pure data persistence
  
✅ DOCUMENT: Create clear architecture diagram
✅ RENAME: Make roles obvious (e.g., HabitCoordinator vs HabitStore)
```

---

### 3.2 Manager Proliferation

**Found 39 "Manager" classes:**

```swift
AuthenticationManager          ✅ OK - Auth is complex
XPManager                      ✅ OK - XP calculations
KeychainManager               ✅ OK - Security concern
SubscriptionManager           ✅ OK - StoreKit integration
NotificationManager           ✅ OK - Notifications
VacationManager              ✅ OK - Vacation logic
ICloudStatusManager          ⚠️  Needed? CloudKit disabled
BackupManager                ✅ OK - Backup orchestration
PermissionManager            ✅ OK - Permission handling
AppRatingManager             ✅ OK - App Store ratings
AchievementManager           ✅ OK - Achievement tracking
DeviceManager                ❓ Could be merged?
ThemeManager                 ❓ Just UserDefaults?
TutorialManager              ❓ Just state?
BottomSheetManager           ❓ Just state?
DiskSpaceAlertManager        ❓ Just state?
CompletionStateManager       ❓ Needed?
AuthRoutingManager           ❓ Routing logic?
MigrationTelemetryManager    ✅ OK - Migration tracking
EnhancedMigrationTelemetryManager  ❓ Why two?
UICacheManager               ❓ Just CacheManager?
TransactionManager           ✅ OK - Transaction safety
ConflictResolutionManager    ❌ DELETE - CloudKit archived
CloudKitUniquenessManager    ❌ DELETE - CloudKit archived
CloudKitSyncManager          ❌ DELETE - CloudKit archived
MigrationStateDataManager    ❓ Merge with MigrationManager?
HabitStorageManager          ❓ Overlaps with Repository?
OptimizedHabitStorageManager ❓ Merge with Storage?
DataRetentionManager         ✅ OK - Retention policies
BackgroundQueueManager       ✅ OK - Background processing
DataMigrationManager         ✅ OK - Migration coordination
CacheManager<K,V>            ✅ OK - Generic cache
AvatarManager                ❓ Just state?
I18nPreferencesManager       ❓ Just UserDefaults?
FeatureFlagManager           ✅ OK - Feature flags
EncryptionKeychainManager    ✅ OK - Encryption
BackupSettingsManager        ✅ OK - Settings management
FieldLevelEncryptionManager  ✅ OK - Encryption
```

**Recommendation**:
```
❌ DELETE: CloudKit-related managers (3 files)
🔀 MERGE: MigrationTelemetryManager + EnhancedMigrationTelemetryManager
🔀 CONSIDER: ThemeManager → UserDefaults extension
🔀 CONSIDER: TutorialManager → @Published var in AppState
⚠️  REVIEW: Do we need 3 storage managers?
```

---

### 3.3 Protocol Analysis

**Found 20 protocols across 16 files.**

**Protocols with single conformance (over-engineering):**

1. **DataStorageProtocol** - 1 conformance (SwiftDataStorage)
   - Could just use concrete type

2. **TimeZoneProvider** - Likely 1 conformance
   - Abstract for testing? Check usage

3. **NowProvider** - Likely 1 conformance
   - Abstract for testing? Check usage

**Protocols with value:**
- `HabitRepositoryProtocol` - 3 conformances (good for testing)
- Various validation protocols

**Recommendation**:
```
⚠️  REVIEW: Each protocol - does it have >1 conformance?
⚠️  QUESTION: Is the abstraction worth the complexity?
✅ KEEP: Protocols used for dependency injection in tests
❌ REMOVE: Single-conformance protocols (use concrete types)
```

---

### 3.4 Dependency Injection Analysis

**101 .shared singletons found!**

**Heavy users of .shared:**
- Most managers use .shared pattern
- Most services use .shared pattern
- Storage layers use .shared
- Utilities use .shared

**Pros:**
- Easy to access
- No need for DI plumbing

**Cons:**
- Hard to test (global state)
- Hidden dependencies
- Potential initialization order issues
- Circular dependency risks

**Current testing strategy:**
- Some singletons are testable (can inject mocks)
- Some use protocols for testing
- Some are hard-coded

**Circular dependency concerns:**

Example from audit:
```swift
HabitRepository.shared
  → calls HabitStore.shared
    → calls SwiftDataContainer.shared
      → calls AuthenticationManager.shared
        → might call HabitRepository? (check!)
```

**Recommendation**:
```
✅ KEEP: .shared for true singletons (managers, caches)
🔀 REPLACE: .shared with DI for testable components
✅ DOCUMENT: Initialization order in docs
✅ TEST: Check for circular dependencies at startup
```

---

## 🔒 4. Safety & Error Handling

### 4.1 Error Handling Gaps

**try? (silent errors): 266 instances across 68 files**

Highest concentration:
- `Core/Data/SwiftData/SwiftDataStorage.swift` - 10 instances
- `Core/Models/HabitDataModel.swift` - 10 instances
- `Core/Services/EventCompactor.swift` - 6 instances
- `Core/Data/OptimizedHabitStorageManager.swift` - 8 instances

**Example bad patterns:**
```swift
// Silent failure - no logging!
let habits = try? loadHabits()

// Better pattern:
do {
    let habits = try loadHabits()
} catch {
    logger.error("Failed to load habits: \(error)")
    CrashlyticsService.shared.record(error)
}
```

**try! (crash risk): 1 instance found!**
- Location: `Core/Managers/EnhancedMigrationTelemetryManager.swift`
- **CRITICAL**: Review this usage immediately

**Recommendation**:
```
❌ REMOVE: All try! - replace with proper error handling
⚠️  AUDIT: All try? - add logging to catch blocks
✅ USE: try + do/catch with proper error reporting
✅ LOG: All errors to OSLog + Crashlytics
```

---

### 4.2 Force Unwraps Analysis ⚠️ **HIGH RISK**

**995 force unwraps (!) across 187 files**

**Heavy users:**
- `Core/Data/CalendarGridViews.swift` - 12 unwraps
- `Core/UI/Components/QuickStatsRow.swift` - 1 unwrap
- ...and 185 more files

**Common patterns:**
```swift
// Date calculations (probably safe but risky)
let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!

// Dictionary access (risky if key missing)
let value = dict[key]!

// Array subscripting (can crash)
let first = array[0]!
```

**Recommendation**:
```
🔍 AUDIT: All 995 force unwraps
✅ REPLACE: With guard/if let or ?? default
⚠️  PRIORITIZE: User-facing code paths first
✅ ADD: Precondition checks where assumptions are valid
```

---

### 4.3 Data Integrity Checks

**userId validation found in 30 locations:**

Good patterns:
```swift
// Explicit empty check
if userId.isEmpty || userId == "guest" {
    return guestData
}

// Clear logging
logger.info("Loading for userId: '\(userId.isEmpty ? "EMPTY" : userId)'")
```

**Potential data leak risks:**

1. **Guest mode checks inconsistent**
   - Some code checks `isEmpty`
   - Some checks `== "guest"`
   - Some checks both
   - Need standardized check

2. **userId filter at query time**
   - Good: SwiftData predicates filter by userId
   - Risk: If predicate malformed, could leak data

3. **Empty userId handling**
   - 30 explicit checks for empty userId
   - Could guest data leak to authenticated users if empty check fails?

**Recommendation**:
```swift
// Standardize empty/guest check
extension String {
    var isGuestUserId: Bool {
        self.isEmpty || self == "guest"
    }
}

// Always validate userId at storage boundary
func loadHabits(for userId: String) async throws -> [Habit] {
    precondition(!userId.isEmpty, "userId must not be empty")
    // ... load habits
}
```

---

### 4.4 Race Conditions

**Concurrent saves found:**
- `modelContext.save()` called from multiple places
- No explicit locking around save operations
- SwiftData handles some concurrency, but...

**Potential race conditions:**

1. **Habit update + Completion update**
```swift
// Thread A
habit.name = "New Name"
try modelContext.save()

// Thread B (simultaneous)
habit.completionHistory[date] = 1
try modelContext.save()

// Risk: Lost update if not properly isolated
```

2. **Streak calculation + Data modification**
```swift
// Calculating streak while habits are being modified
// Could read inconsistent state
```

**Actor isolation helps:**
- `HabitStore` is an actor ✅
- But SwiftData operations are @MainActor

**Recommendation**:
```
✅ USE: Serial queue for related operations
✅ BATCH: Related saves in single transaction
✅ VERIFY: SwiftData concurrency guarantees
⚠️  TEST: Race condition scenarios
```

---

## 📊 5. Logging & Observability

### 5.1 Logging Cleanup ⚠️ **CRITICAL**

**print() statements: 2,421 in Core/ across 113 files!**

**Worst offenders:**
- `Core/Models/Habit.swift` - 38 prints
- `Core/Data/Repository/HabitStore.swift` - 29 prints
- `Core/Data/SwiftData/SwiftDataStorage.swift` - 108 prints (!!)
- `Core/Services/FirestoreService.swift` - 42 prints
- `Core/Managers/AuthenticationManager.swift` - 81 prints
- `Core/Managers/SubscriptionManager.swift` - 332 prints (!!!)
- `Core/Managers/NotificationManager.swift` - 188 prints

**Issues:**
1. **Performance**: print() synchronously writes to console
2. **Production**: All these prints ship to production
3. **Privacy**: May log sensitive data
4. **Debugging**: Too much noise to find real issues

**OSLog/Logger usage: 240 instances** (better but inconsistent)

**Recommendation**:
```swift
// Create standardized logger
import OSLog

extension Logger {
    static let habits = Logger(subsystem: "com.habitto", category: "habits")
    static let sync = Logger(subsystem: "com.habitto", category: "sync")
    static let auth = Logger(subsystem: "com.habitto", category: "auth")
}

// Replace ALL print() with Logger
// Before:
print("Loading habits...")

// After:
Logger.habits.debug("Loading habits")

// Benefit: Automatic level filtering in production
```

**Action plan:**
```
1. ❌ REMOVE: All print() in production paths
2. ✅ REPLACE: With OSLog/Logger
3. 🔍 AUDIT: For PII in log statements
4. ✅ ADD: #if DEBUG for verbose logs
```

---

### 5.2 Inconsistent Log Prefixes

**Found patterns:**
```
🔥 STREAK_CALC:
📊 LONGEST_STREAK:
🔍 OVERVIEW_STREAK:
🔄 [MIGRATION]
🎯 [8/8] SwiftDataStorage
✅ MIGRATION:
⚠️  [HABIT_STORE]
🔐 HabitRepository:
```

**Issues:**
- No standard format
- Hard to filter/search
- Emojis may not render in all tools
- Mixed [BRACKETS] and UNDERSCORES

**Recommendation**:
```
✅ STANDARDIZE: Pick one format
  Option A: [CATEGORY] Message
  Option B: CATEGORY: Message
  
✅ CREATE: Logging guidelines doc
✅ USE: OSLog categories instead of prefixes
```

---

### 5.3 Missing Observability

**Timing metrics:**
- Some functions have `CFAbsoluteTimeGetCurrent()` timing
- Most don't

**User action tracking:**
- Analytics exists (`UserAnalytics.swift`)
- But not consistently used

**Error rates:**
- No centralized error rate tracking
- Crashlytics is used but not everywhere

**Recommendation**:
```swift
// Add timing decorator
func measured<T>(_ name: String, _ block: () throws -> T) rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    defer {
        let duration = CFAbsoluteTimeGetCurrent() - start
        PerformanceMetrics.shared.record(name, duration: duration)
    }
    return try block()
}

// Use:
let habits = try measured("loadHabits") {
    try await loadHabits()
}
```

---

## 🎨 6. SwiftUI Optimization

### 6.1 View Performance

**Large body properties:**
- `Views/Tabs/ProgressTabView.swift` - **5,767 lines** (!!!)
- This should be broken into subviews

**View observation:**
- `@StateObject`: 94 instances ✅
- `@ObservedObject`: 94 instances ✅
- `@EnvironmentObject`: reasonable usage

**ForEach usage: 160 instances**
- Most appear to have proper `id:` parameters
- Some use `.indices` which is OK

**Recommendation**:
```
❌ BREAK UP: ProgressTabView.swift (5,767 lines → <500 line files)
✅ USE: @Observable macro for granular updates
✅ PROFILE: Instruments to find view re-render issues
```

---

### 6.2 .onAppear / .task Usage

**83 instances found across 55 files**

**Common patterns:**
```swift
.onAppear {
    loadData() // ⚠️  Synchronous work
}

.task {
    await loadData() // ✅ Good - async
}
```

**Potential issues:**
- Some .onAppear do heavy synchronous work
- Multiple .onAppear chained = multiple calls

**Recommendation**:
```
✅ PREFER: .task over .onAppear for async work
✅ DEBOUNCE: Rapid appear/disappear cycles
⚠️  AVOID: Heavy work in .onAppear
```

---

## 🔥 7. Firebase/Cloud Optimization

### 7.1 Firestore Efficiency

**No unbounded queries found** ✅ (good!)

**Potential batching opportunities:**
- Completion records loaded per-habit
- Could batch into single query

**Index verification needed:**
```
Check firestore.indexes.json for all query patterns
```

**Recommendation**:
```
✅ VERIFY: All composite queries have indexes
✅ BATCH: Multi-habit queries where possible
✅ CACHE: Firestore query results client-side
```

---

### 7.2 Sync Status Monitoring

**Good: HabitRepository has sync status**
```swift
@Published var syncStatus: HabitSyncStatus = .synced
@Published var unsyncedCount: Int = 0
@Published var lastSyncDate: Date?
```

**Sync health monitoring exists:**
- `Core/Services/SyncHealthMonitor.swift`

**Recommendation**: Already well-architected ✅

---

## 🧪 8. Testing Gaps

### 8.1 Test Coverage

**Test files found:**
```
Tests/firestore.rules.test.js
Tests/GoldenScenarios/
Tests/Migration/MigrationTestRunner.swift
Tests/Migration/SchemaMigrationTestRunner.swift
Tests/WidgetTimezoneTest.swift
```

**Missing:**
- Unit tests for Core/Models
- Unit tests for Core/Services
- Unit tests for streak calculation
- UI tests for critical flows

**Recommendation**:
```
✅ ADD: Unit tests for StreakCalculator
✅ ADD: Unit tests for data migrations
✅ ADD: Integration tests for sync
✅ ADD: UI tests for habit creation flow
```

---

## 🗑️ 9. Technical Debt Specific to Habitto

### 9.1 Archive Folders

**28 files in Archive/ folders:**

```
DELETE CANDIDATES:
├── Core/Data/CloudKit/Archive/ (8 files) - CloudKit disabled
├── Core/Services/Archive/ (5 files) - Old service pattern
├── Core/Migration/Archive/ (6 files) - Old migrations
├── Core/Models/Archive/New/ (8 files) - Old models
└── Core/Utils/Archive/ (2 files) - Old utilities
```

**Estimate:** ~3,000-5,000 lines of dead code

**Recommendation**:
```
❌ DELETE ALL: Archive folders
✅ COMMIT: Before deleting, ensure git history preserved
✅ DOCUMENT: Where to find old code if needed
```

---

### 9.2 Feature Flags

**FeatureFlags.swift exists:**
```swift
static let shared = NewArchitectureFlags()
```

**Recommendation:**
```
🔍 AUDIT: Which flags are always on/off?
❌ REMOVE: Flags that are always on (remove flag + old code)
❌ REMOVE: Flags that are always off (remove flag + new code)
```

---

## 📝 10. Documentation Audit

### 10.1 Missing Documentation

**Found good documentation:**
- `Docs/Architecture/` - 8 markdown files
- `Docs/Features/` - 6 markdown files
- Many inline comments

**Missing:**
- API documentation for public methods
- Architecture decision records (ADRs)
- How to test locally

**Recommendation**:
```
✅ ADD: /// doc comments for public APIs
✅ CREATE: ARCHITECTURE.md with layer diagram
✅ CREATE: TESTING.md with how-to guide
```

---

## 🏃 Quick Wins (Immediate Actions)

### High Impact, Low Effort:

1. **Delete Archive folders** ❌
   - 28 files, ~3,000 LOC
   - Impact: Codebase clarity
   - Effort: 1 hour

2. **Delete CloudKit imports** ❌
   - 10 files importing disabled feature
   - Impact: Reduce confusion
   - Effort: 30 minutes

3. **Standardize userId checks** ✅
   - Create `isGuestUserId` extension
   - Impact: Security
   - Effort: 2 hours

4. **Fix try! in EnhancedMigrationTelemetryManager** ❌
   - 1 crash risk
   - Impact: Stability
   - Effort: 15 minutes

5. **Cache DateFormatters** ✅
   - Replace 293 instances with cached
   - Impact: Performance
   - Effort: 4 hours

6. **Consolidate streak calculation** ✅
   - Use StreakCalculator everywhere
   - Impact: Maintainability
   - Effort: 8 hours

---

## 📊 Priority Matrix

### 🔴 CRITICAL (Do First):
1. Fix try! crash risk
2. Audit force unwraps in user-facing code
3. Delete Archive folders (code confusion)
4. Replace print() with Logger (2,421 instances!)

### 🟠 HIGH (Do Soon):
1. Consolidate streak calculation logic
2. Cache DateFormatters (performance)
3. Standardize userId validation (security)
4. Break up ProgressTabView (5,767 lines)

### 🟡 MEDIUM (Do Eventually):
1. Simplify architecture (3 layers → 2)
2. Remove unused .shared singletons
3. Audit @Published updates in loops
4. Add unit test coverage

### 🟢 LOW (Nice to Have):
1. Consolidate Manager classes
2. Remove single-conformance protocols
3. Standardize log prefixes
4. Add API documentation

---

## 📈 Metrics Summary

| Metric | Count | Status | Action Needed |
|--------|-------|--------|---------------|
| print() statements | 2,421 | 🔴 Critical | Replace with Logger |
| Force unwraps (!) | 995 | 🔴 Critical | Audit & replace |
| try? (silent) | 266 | 🟠 High | Add error logging |
| try! (crash) | 1 | 🔴 Critical | Fix immediately |
| .shared singletons | 101 | 🟡 Medium | Review necessity |
| @Published properties | 233 | 🟢 OK | Audit loop updates |
| DateFormatter creates | 293 | 🟠 High | Cache instances |
| Archive files | 28 | 🔴 Critical | Delete |
| CloudKit imports | 10 | 🟠 High | Delete |
| Manager classes | 39 | 🟡 Medium | Consolidate some |
| Protocol definitions | 20 | 🟢 OK | Review single-use |
| modelContext.save() | 91 | 🟡 Medium | Batch operations |
| Duplicate streak functions | 5+ | 🟠 High | Consolidate to 1 |

---

## 🎯 Recommended Action Plan

### Phase 1: Safety & Cleanup (Week 1)
- [ ] Fix try! crash risk
- [ ] Delete Archive/ folders
- [ ] Delete CloudKit imports
- [ ] Create userId validation standard

### Phase 2: Performance (Week 2)
- [ ] Cache DateFormatters
- [ ] Replace print() with Logger (top 10 files)
- [ ] Audit force unwraps (user-facing code)
- [ ] Batch modelContext.save() calls

### Phase 3: Architecture (Week 3-4)
- [ ] Consolidate streak calculation
- [ ] Break up ProgressTabView
- [ ] Document architecture layers
- [ ] Review .shared singletons

### Phase 4: Testing & Docs (Week 5)
- [ ] Add unit tests for core logic
- [ ] Add API documentation
- [ ] Create ARCHITECTURE.md
- [ ] Create TESTING.md

---

## 📚 Additional Files to Review

Based on this audit, prioritize reviewing:

1. **ProgressTabView.swift** (5,767 lines)
2. **HabitRepository.swift** (1,843 lines)
3. **HabitStore.swift** (1,529 lines)
4. **SwiftDataStorage.swift** (1,286 lines)
5. **SubscriptionManager.swift** (332 prints!)
6. **NotificationManager.swift** (188 prints)

---

## ✅ Conclusion

The Habitto codebase is well-structured overall, with good use of modern Swift patterns (actors, async/await, SwiftData). However, there are significant opportunities for improvement:

**Strengths:**
- ✅ SwiftData migration complete
- ✅ Actor-based concurrency
- ✅ Good separation of concerns
- ✅ Comprehensive documentation files

**Weaknesses:**
- ❌ 2,421 print() statements
- ❌ 995 force unwraps
- ❌ 28 archived files still present
- ❌ Duplicate streak calculation logic
- ❌ Some files are too large (5,767 lines)

**Key Recommendation:**
Focus on **Phase 1** (Safety & Cleanup) immediately. The combination of fixing the try! crash, deleting dead code, and standardizing logging will have the highest impact on code quality and maintainability.

---

*End of Audit Report*
