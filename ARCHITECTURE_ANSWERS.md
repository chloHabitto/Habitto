# Architecture Analysis - Complete Answers

## Core Architecture Questions

### 1. SwiftData/ModelContext Persistence Layer Architecture

**Files that interact with SwiftData/ModelContext:**
- `Core/Data/SwiftData/SwiftDataContainer.swift` - Main container manager
- `Core/Data/SwiftData/SwiftDataStorage.swift` - Primary storage implementation
- `Core/Data/SwiftData/HabitDataModel.swift` - All SwiftData models
- `Core/Data/Repository/HabitStore.swift` - Actor that handles data operations
- `Core/Data/HabitRepository.swift` - Main repository (MainActor facade)
- `App/HabittoApp.swift` - App initialization and ModelContainer setup
- `Core/Managers/XPManager.swift` - XP data loading
- `Views/Screens/HomeView.swift` - UI queries
- `Views/Tabs/HomeTabView.swift` - UI queries

**Current Architecture:**
- **Primary Storage**: SwiftData (SQLite backend)
- **Data Flow**: `UI Layer → HabitRepository (@MainActor) → HabitStore (Actor) → SwiftDataStorage → SQLite`
- **Container**: Single shared `SwiftDataContainer.shared.modelContainer` with versioned schema (`HabittoSchemaV1`)
- **Migration System**: Uses `HabittoMigrationPlan` for schema migrations
- **User Isolation**: Data scoped by `userId` field (guest = `""`)
- **CloudKit**: Disabled (infrastructure exists but commented out)

### 2. Firebase Integration

**Yes, Firebase is integrated:**

**Files with Firebase imports:**
- `App/HabittoApp.swift` - FirebaseCore, FirebaseAuth, FirebaseFirestore, FirebaseCrashlytics, FirebaseRemoteConfig
- `App/AppFirebase.swift` - Centralized Firebase configuration
- `Core/Managers/AuthenticationManager.swift` - Firebase Auth
- `Core/Services/FirestoreService.swift` - Firestore operations
- `Core/Data/Sync/SyncEngine.swift` - Event sync to Firestore
- `Core/Data/Firestore/FirestoreRepository.swift` - Firestore repository
- `Core/Data/Storage/DualWriteStorage.swift` - Dual-write to Firestore
- `Core/Data/SwiftData/SwiftDataContainer.swift` - FirebaseAuth import

**Current State:**
- Firebase is configured and initialized in `AppDelegate.didFinishLaunchingWithOptions`
- Firestore has offline persistence enabled
- Firebase Auth supports Google Sign-In, Apple Sign-In, Email/Password
- **Anonymous Auth**: Currently disabled/removed (guest mode uses empty string userId)
- Firestore sync exists but is feature-flag protected
- Backup service uses Firestore for cloud backups

### 3. Habit Model Structure

**Complete Habit Model:**

**SwiftData Model** (`Core/Data/SwiftData/HabitDataModel.swift`):
```swift
@Model
final class HabitData {
    @Attribute(.unique) var id: UUID
    var userId: String  // User isolation
    var name: String
    var habitDescription: String
    var icon: String
    var colorData: Data  // Color encoded as Data
    var habitType: String  // Enum as String
    var schedule: String
    var goal: String
    var reminder: String
    var goalHistoryJSON: String = "{}"
    var startDate: Date
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var baseline: Int = 0  // For breaking habits
    var target: Int = 1    // For breaking habits
    
    // Relationships
    @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
    @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
    @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
    @Relationship(deleteRule: .cascade) var notes: [HabitNote]
}
```

**Domain Model** (`Core/Models/Habit.swift`):
```swift
struct Habit: Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let color: CodableColor
    let habitType: HabitType
    let schedule: String
    let goal: String
    let reminder: String
    let reminders: [ReminderItem]
    let startDate: Date
    let endDate: Date?
    let createdAt: Date
    
    // Progress tracking (denormalized, computed from CompletionRecords)
    var completionHistory: [String: Int]  // "yyyy-MM-dd" -> progress count
    var completionStatus: [String: Bool]  // "yyyy-MM-dd" -> completed/incomplete
    var completionTimestamps: [String: [Date]]  // "yyyy-MM-dd" -> [completion_times]
    var difficultyHistory: [String: Int]  // "yyyy-MM-dd" -> difficulty (1-10)
    var goalHistory: [String: String]  // "yyyy-MM-dd" -> goal string
    var actualUsage: [String: Int]  // For breaking habits
    
    // Breaking habit fields
    var baseline: Int = 0
    var target: Int = 0
    
    // Sync metadata
    var lastSyncedAt: Date?
    var syncStatus: FirestoreSyncStatus = .pending
}
```

### 4. HabitRepository Implementation

**Main Repository** (`Core/Data/HabitRepository.swift`):
- `@MainActor class HabitRepository: ObservableObject`
- Acts as facade for UI layer
- Delegates to `HabitStore` actor for actual operations

**Key Methods:**
- `loadHabits(force: Bool)` - Loads habits from storage
- `saveHabits(_ habits: [Habit], immediate: Bool)` - Saves habits
- `create(_ item: Habit)` - Creates new habit
- `update(_ item: Habit)` - Updates existing habit
- `delete(_ id: UUID)` - Deletes habit
- `getHabits(for date: Date)` - Gets habits active on date
- `getActiveHabits()` - Gets all active habits
- `markComplete(habitId: String, date: Date, count: Int)` - Marks habit complete

**HabitStore Actor** (`Core/Data/Repository/HabitStore.swift`):
- `final actor HabitStore` - Handles all data operations off main thread
- `loadHabits()` - Loads from active storage (SwiftData)
- `saveHabits(_ habits: [Habit])` - Validates, caps history, saves to SwiftData
- `clearAllHabits(for userId: String?)` - Clears user data
- Handles migrations, data retention, validation

**Storage Layer** (`Core/Data/SwiftData/SwiftDataStorage.swift`):
- `saveHabits(_ habits: [Habit], immediate: Bool)` - Converts Habit → HabitData, saves to ModelContext
- `loadHabits()` - Loads HabitData from ModelContext, converts to Habit
- `saveHabit(_ habit: Habit, immediate: Bool)` - Saves single habit
- `loadHabit(id: UUID)` - Loads single habit
- `deleteHabit(id: UUID)` - Deletes habit

### 5. Cloud Storage/Sync

**Current State:**
- **CloudKit**: Infrastructure exists but **DISABLED** (entitlements commented out)
- **Firebase Firestore**: Integrated and configured, but sync is feature-flag protected
- **Sync Engine**: `Core/Data/Sync/SyncEngine.swift` - Handles event-based sync to Firestore
- **Background Tasks**: Registered in `App-Info.plist` for backup and event compaction

**CloudKit Files:**
- `Core/Data/CloudKitManager.swift` - Manager (returns false for availability)
- `Core/Data/CloudKit/CloudKitSyncManager.swift` - Sync manager (disabled)
- `Core/Data/CloudKit/CloudKitModels.swift` - CloudKit models
- `Core/Data/CloudKit/CloudKitIntegrationService.swift` - Integration service

**Firebase Sync:**
- `Core/Data/Sync/SyncEngine.swift` - Main sync engine
- `Core/Services/FirestoreService.swift` - Firestore operations
- `Core/Data/Storage/DualWriteStorage.swift` - Dual-write pattern (local-first, then Firestore)
- `Core/Services/BackupScheduler.swift` - Scheduled backups to Firestore

**Network Calls:**
- Firestore operations via Firebase SDK
- Background tasks for sync (`BGTaskScheduler`)
- No direct URLSession calls for data sync

## User ID & Data Association

### 6. User Identification System

**Current System:**
- **Guest Mode**: Uses empty string `""` as userId
- **Authenticated Users**: Uses Firebase Auth UID
- **Helper**: `Core/Models/CurrentUser.swift` - Provides safe user ID access

**Key Files:**
- `Core/Models/CurrentUser.swift` - Always returns `""` (guest mode only currently)
- `Core/Managers/AuthenticationManager.swift` - Manages Firebase Auth
- `Core/Data/SwiftData/SwiftDataContainer.swift` - Gets userId from Firebase Auth

**userId Usage:**
- All SwiftData models have `userId: String` field
- Data is filtered by userId in queries
- Guest data uses `userId = ""`
- Migration code exists to move guest data to authenticated users

### 7. Habit Creation Flow

**Complete Flow:**

1. **UI Layer** (`Views/Flows/CreateHabitStep2View.swift`):
   - User fills out habit form
   - Creates `Habit` domain object

2. **Repository Layer** (`Core/Data/HabitRepository.swift`):
   - `create(_ item: Habit)` called
   - Delegates to `HabitStore.shared.create()` or `saveHabits()`

3. **HabitStore Actor** (`Core/Data/Repository/HabitStore.swift`):
   - `saveHabits(_ habits: [Habit])` called
   - Validates habits
   - Caps history data
   - Sanitizes end dates
   - Calls `activeStorage.saveHabits()`

4. **SwiftDataStorage** (`Core/Data/SwiftData/SwiftDataStorage.swift`):
   - `saveHabits(_ habits: [Habit], immediate: Bool)` called
   - Gets current userId (guest = `""`)
   - For each habit:
     - Converts `Habit` → `HabitData`
     - Sets `userId` field
     - Inserts into ModelContext
     - Creates/updates `CompletionRecord` relationships
   - Calls `modelContext.save()`

5. **Persistence**:
   - SwiftData saves to SQLite database
   - If Firestore sync enabled, also syncs to Firestore (background)

**Key Code Locations:**
- `Core/Data/SwiftData/SwiftDataStorage.swift:508-559` - Save implementation
- `Core/Data/SwiftData/HabitDataModel.swift:144-289` - HabitData update methods

### 8. SwiftData Models with userId

**All Models Have userId:**

1. **HabitData** (`Core/Data/SwiftData/HabitDataModel.swift:56-57`):
   ```swift
   @Attribute(.unique) var id: UUID
   var userId: String  // User ID for data isolation
   ```

2. **CompletionRecord** (`Core/Data/SwiftData/HabitDataModel.swift:553`):
   ```swift
   var userId: String
   var habitId: UUID
   @Attribute(.unique) var userIdHabitIdDateKey: String  // Composite key
   ```

3. **DailyAward** (`Core/Models/DailyAward.swift:23`):
   ```swift
   public var userId: String
   @Attribute(.unique) public var userIdDateKey: String  // Composite key
   ```

4. **UserProgressData** (referenced in code):
   - Has `userId: String` field
   - Stores XP, level, streak data per user

**Note**: `DifficultyRecord`, `UsageRecord`, `HabitNote` don't have userId fields (they use relationships to HabitData which has userId)

## Migration Preparedness

### 9. Adding userId Field to Models

**Models Already Have userId:**
- ✅ `HabitData` - Has userId
- ✅ `CompletionRecord` - Has userId
- ✅ `DailyAward` - Has userId
- ✅ `UserProgressData` - Has userId (referenced in code)

**Models That Don't Need userId** (use relationships):
- `DifficultyRecord` - Linked via `HabitData.difficultyHistory`
- `UsageRecord` - Linked via `HabitData.usageHistory`
- `HabitNote` - Linked via `HabitData.notes`

**If Adding userId to Existing Data:**
- Migration code exists in `App/HabittoApp.swift`:
  - `diagnoseAndMigrateOldUserData()` - Migrates data from old userIds
  - `repairUserIdMismatches()` - Fixes userId mismatches
- Would need to:
  1. Add userId field to schema (if not present)
  2. Run migration to populate userId for existing records
  3. Update all queries to filter by userId

### 10. Data Migration Logic

**Migration System Exists:**

**Files:**
- `Core/Data/SchemaVersion.swift` - Schema versioning system
- `Core/Data/Migration/DataMigrationManager.swift` - Main migration manager
- `Core/Services/MigrationService.swift` - Migration service
- `Core/Data/SwiftData/SwiftDataContainer.swift` - Uses `HabittoMigrationPlan`
- `App/HabittoApp.swift` - Contains migration helpers

**Migration Features:**
- Versioned schema (`HabittoSchemaV1`)
- Migration plan (`HabittoMigrationPlan`)
- Step-based migrations with rollback support
- Idempotent migrations (can run multiple times safely)
- Resume token system for crash recovery
- Telemetry tracking

**Migration Types:**
- Schema migrations (SwiftData schema changes)
- Data migrations (UserDefaults → SwiftData)
- Guest-to-auth migrations
- User ID repair migrations

## Current State Assessment

### 11. App Initialization Flow

**HabittoApp.swift Initialization:**

1. **AppDelegate.didFinishLaunchingWithOptions**:
   - Configures Firebase (FirebaseBootstrapper)
   - Sets up Remote Config
   - Sets up AuthenticationManager listener
   - Registers background tasks
   - Runs completion status migration
   - Runs event-sourcing migration

2. **HabittoApp.body**:
   - Shows splash screen
   - Initializes managers (NotificationManager, HabitRepository, etc.)
   - Sets up ModelContainer from `SwiftDataContainer.shared`
   - On appear:
     - Diagnoses data issues
     - Repairs CompletionRecord relationships
     - Restores progress from Firestore (if needed)
     - Loads habits
     - Loads XP data
     - Runs XP data migration
     - Diagnoses and migrates old user data
     - Repairs userId mismatches
     - Performs XP integrity check
     - Performs CompletionRecord reconciliation

3. **SwiftDataContainer Initialization**:
   - Creates versioned schema with migration plan
   - Handles CloudKit-to-local migration (one-time)
   - Creates ModelContainer
   - Creates ModelContext
   - Tests database accessibility

### 12. Data Backup/Recovery

**Backup Mechanisms:**

1. **Firestore Backup**:
   - `Core/Services/FirestoreService.swift` - Firestore operations
   - `Core/Data/Sync/SyncEngine.swift` - Syncs events to Firestore
   - `Core/Services/BackupScheduler.swift` - Scheduled backups
   - Background tasks registered for backup

2. **Local Storage**:
   - SwiftData (SQLite) - Primary storage
   - UserDefaults - Legacy storage (being migrated away)

3. **Recovery Code**:
   - `App/HabittoApp.swift:1391-1447` - `restoreProgressFromFirestore()`
   - `App/HabittoApp.swift:1402-1447` - `checkUserDefaultsForRecovery()`
   - Migration code can restore from Firestore backups

**No Explicit Backup UI** - Backups happen automatically in background

### 13. All modelContext.save() Calls

**Found 672+ instances of modelContext.save() or ModelContext usage:**

**Key Locations:**
- `Core/Data/SwiftData/SwiftDataStorage.swift` - All save operations
- `Core/Data/SwiftData/SwiftDataContainer.swift` - Container setup
- `Core/Data/SwiftData/HabitDataModel.swift` - Model update methods
- `App/HabittoApp.swift` - Migration and repair operations
- `Views/Screens/HomeView.swift` - UI-driven saves
- `Views/Tabs/HomeTabView.swift` - UI-driven saves
- `Core/Managers/XPManager.swift` - XP data saves

**Primary Save Points:**
1. Habit creation/update (`SwiftDataStorage.saveHabits()`)
2. Completion record updates (`HabitDataModel.syncCompletionRecordsFromHabit()`)
3. Daily award creation (`HomeTabView`)
4. Migration operations (`App/HabittoApp.swift`)
5. User ID repairs (`App/HabittoApp.swift`)

### 14. Background Tasks/Sync Logic

**Background Tasks:**

1. **Registered Tasks** (`App-Info.plist`):
   - `com.habitto.app.backup` - Backup task
   - `com.habitto.app.backup.refresh` - Backup refresh
   - `com.habitto.app.event-compaction` - Event compaction

2. **Background Modes** (`App-Info.plist`):
   - `remote-notification`
   - `processing`

3. **Background Task Files:**
   - `Core/Services/BackupScheduler.swift` - Backup scheduling
   - `Core/Data/Sync/SyncEngine.swift` - Periodic sync (every 5 minutes)
   - Event compaction background handler

4. **Sync Logic:**
   - `SyncEngine.startPeriodicSync()` - Starts periodic sync for authenticated users
   - Skips sync for guest users
   - Syncs events to Firestore
   - Pulls remote changes
   - Pushes local changes

**No URLSession for Data Sync** - Uses Firebase SDK

## Specific Implementation Check

### 15. Guest Mode/Anonymous Users

**Guest Mode Implementation:**

**Files:**
- `Core/Models/CurrentUser.swift` - Always returns `""` for guest
- `Core/Data/SwiftData/SwiftDataStorage.swift` - Guest mode handling
- `App/HabittoApp.swift` - Guest migration code

**Current State:**
- **Anonymous Auth**: Disabled/removed (commented out in code)
- **Guest Mode**: Uses `userId = ""` (empty string)
- **Migration**: Code exists to migrate guest data to authenticated users
- **Guest Data**: Stored with `userId = ""` in SwiftData

**Key Code:**
- `CurrentUser.guestId = ""` - Guest identifier
- `CurrentUser.isGuestId(_ userId: String)` - Checks if guest
- Guest data migration in `App/HabittoApp.swift:880-1115`

### 16. Info.plist Settings

**App-Info.plist Contents:**

**Background Modes:**
- `remote-notification`
- `processing`

**Background Task Identifiers:**
- `com.habitto.app.backup`
- `com.habitto.app.backup.refresh`
- `com.habitto.app.event-compaction`

**URL Schemes:**
- `com.chloe-lee.Habitto` - App URL scheme
- `com.chloe-lee.Habitto.signin` - Apple Sign-In
- Google Sign-In URL scheme

**No iCloud/CloudKit Entitlements** - CloudKit is disabled

### 17. HabitStore Actor Implementation

**Complete HabitStore** (`Core/Data/Repository/HabitStore.swift`):

**Key Methods:**
- `loadHabits() async throws -> [Habit]` - Loads habits, runs migrations
- `saveHabits(_ habits: [Habit]) async throws` - Validates, caps, saves
- `clearAllHabits(for userId: String?) async throws` - Clears user data
- `performCloudKitSync() async throws -> SyncResult` - CloudKit sync (disabled)
- `resolveHabitConflict(_ local: Habit, _ remote: Habit) async -> Habit` - Conflict resolution

**Storage Interaction:**
- Uses `activeStorage` (SwiftDataStorage or DualWriteStorage)
- Handles validation via `DataValidationService`
- Manages data retention via `DataRetentionManager`
- Caps history via `HistoryCapper`

**Actor Pattern:**
- All methods are `async` (actor isolation)
- Called from `HabitRepository` (MainActor) via `await`
- Ensures thread-safe data operations

## Critical Path

### 18. Files to Modify for Firebase Anonymous Auth

**To Add Firebase Anonymous Auth, modify these files:**

**Authentication Layer:**
1. `Core/Managers/AuthenticationManager.swift` - Add anonymous sign-in method
2. `App/AppFirebase.swift` - Re-enable anonymous auth (currently commented out)
3. `Core/Models/CurrentUser.swift` - Update to return Firebase UID instead of `""`

**Data Layer:**
4. `Core/Data/SwiftData/SwiftDataStorage.swift` - Update `getCurrentUserId()` to return Firebase UID
5. `Core/Data/SwiftData/SwiftDataContainer.swift` - Update userId resolution
6. `Core/Data/Repository/HabitStore.swift` - Ensure userId is set correctly
7. `Core/Data/HabitRepository.swift` - No changes needed (uses HabitStore)

**Migration Layer:**
8. `App/HabittoApp.swift` - Update guest migration logic
   - `migrateGuestDataToAnonymousUser()` - Already exists, needs activation
   - `diagnoseAndMigrateOldUserData()` - May need updates
   - `repairUserIdMismatches()` - May need updates

**Sync Layer:**
9. `Core/Data/Sync/SyncEngine.swift` - Update to sync anonymous user data
10. `Core/Services/FirestoreService.swift` - Ensure anonymous users can write to Firestore

**App Initialization:**
11. `App/HabittoApp.swift` - Re-enable anonymous auth in `AppDelegate.didFinishLaunchingWithOptions`
    - Uncomment lines 92-165 (anonymous auth setup)

**Total: ~11 files to modify**

**Key Changes:**
1. Call `Auth.auth().signInAnonymously()` on app launch
2. Use Firebase UID instead of `""` for userId
3. Migrate existing guest data (`userId = ""`) to anonymous user UID
4. Enable Firestore sync for anonymous users
5. Update all userId queries to use Firebase UID
