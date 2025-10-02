# Dual-Storage & Cache Detector - Storage Inventory

## UserDefaults Usage

### 1. Habit Storage
**File**: `Core/Models/Habit.swift:7`
```swift
private let userDefaults = UserDefaults.standard
private let habitsKey = "SavedHabits"
```
**Classification**: [Business data ➜ must migrate]
**Key**: `"SavedHabits"`
**Value Type**: `Data` (encoded `[Habit]`)

### 2. XP Progress Storage
**File**: `Core/Managers/XPManager.swift:23-25`
```swift
private let userDefaults = UserDefaults.standard
private let userProgressKey = "user_progress"
private let recentTransactionsKey = "recent_xp_transactions"
private let dailyAwardsKey = "daily_xp_awards"
```
**Classification**: [Business data ➜ must migrate]
**Keys**: 
- `"user_progress"` - Value Type: `Data` (encoded `UserProgress`)
- `"recent_xp_transactions"` - Value Type: `Data` (encoded `[XPTransaction]`)
- `"daily_xp_awards"` - Value Type: `Data` (encoded `[String: Set<UUID>]`)

### 3. Migration State Storage
**File**: `Core/Data/HabitRepository.swift:148`
```swift
// UserDefaults for storing migration attempt counts
private let userDefaults = UserDefaults.standard
```
**Classification**: [Business data ➜ must migrate]
**Usage**: Migration attempt counts and state

### 4. XP Data Migration
**File**: `Core/Managers/XPDataMigration.swift:20`
```swift
if UserDefaults.standard.bool(forKey: migrationKey) {
```
**Classification**: [Business data ➜ must migrate]
**Key**: `migrationKey` (specific key not shown in snippet)

### 5. Legacy Habit Storage Check
**File**: `Core/Data/Repository/HabitStore.swift:156`
```swift
if let habitsData = UserDefaults.standard.data(forKey: key) {
```
**Classification**: [Business data ➜ must migrate]
**Keys**: 
- `"SavedHabits"`
- `"Habits"`
- `"UserHabits"`
- `"LegacyHabits"`

### 6. Migration Completion Flag
**File**: `Core/Data/Repository/HabitStore.swift` (referenced in data_layer_fix_plan.md:508)
```swift
userDefaults.set(true, forKey: "migration_to_swiftdata_complete")
```
**Classification**: [Business data ➜ must migrate]
**Key**: `"migration_to_swiftdata_complete"`

## @AppStorage Usage

### 1. UI Preferences (Found in Views)
**File**: Various view files
**Classification**: [UI preference]
**Usage**: Theme settings, last selected tab, UI state

## Keychain Usage

### 1. Authentication Tokens
**File**: `Core/Data/HabitRepository.swift:124`
```swift
// User tokens → Keychain (via KeychainManager)
```
**Classification**: [UI preference] - Authentication data
**Usage**: Firebase/Apple/Google tokens

## NSUbiquitousKeyValueStore Usage

**Search Result**: None found
**Classification**: N/A

## In-Memory Singletons/Caches

### 1. XPManager Singleton
**File**: `Core/Managers/XPManager.swift:17`
```swift
@MainActor
class XPManager: ObservableObject {
    static let shared = XPManager()
    @Published var userProgress = UserProgress()
    @Published var recentTransactions: [XPTransaction] = []
```
**Classification**: [Business data ➜ must migrate]
**Issue**: Cached business data that survives app lifecycle

### 2. HabitRepository Singleton
**File**: `Core/Data/HabitRepository.swift:129`
```swift
@MainActor
class HabitRepository: ObservableObject {
    static let shared = HabitRepository()
    @Published var habits: [Habit] = []
```
**Classification**: [Business data ➜ must migrate]
**Issue**: Cached business data that survives app lifecycle

### 3. HabitStorageManager Singleton
**File**: `Core/Models/Habit.swift:4`
```swift
class HabitStorageManager {
    static let shared = HabitStorageManager()
    // Performance optimization: Cache loaded habits
    private var cachedHabits: [Habit]?
```
**Classification**: [Business data ➜ must migrate]
**Issue**: Cached business data that survives app lifecycle

### 4. HabitStore Actor
**File**: `Core/Data/Repository/HabitStore.swift:10`
```swift
final actor HabitStore {
    static let shared = HabitStore()
```
**Classification**: [Business data ➜ must migrate]
**Issue**: Actor-based storage that may cache data

## Storage Classification Summary

| Storage Type | Classification | Count | Critical Issues |
|--------------|---------------|-------|-----------------|
| UserDefaults (Business) | [Business data ➜ must migrate] | 6+ keys | Dual storage with SwiftData |
| UserDefaults (UI) | [UI preference] | Multiple | ✅ Acceptable |
| Keychain | [UI preference] | Auth tokens | ✅ Acceptable |
| @AppStorage | [UI preference] | UI state | ✅ Acceptable |
| Singletons | [Business data ➜ must migrate] | 4 classes | Data leakage between users |
| NSUbiquitousKeyValueStore | N/A | 0 | None found |

## Critical Issues Found

### 1. Dual Storage System
- **Habits**: Stored in both UserDefaults (`"SavedHabits"`) and SwiftData
- **XP Data**: Stored in both UserDefaults (`"user_progress"`, `"recent_xp_transactions"`, `"daily_xp_awards"`) and SwiftData
- **Migration State**: Tracked in UserDefaults but not properly isolated by user

### 2. Sticky Singletons
- **XPManager.shared**: Caches user progress, survives sign-out
- **HabitRepository.shared**: Caches habits, survives sign-out  
- **HabitStorageManager.shared**: Caches habits, survives sign-out
- **HabitStore.shared**: Actor-based storage, may cache data

### 3. User Isolation Issues
- **UserDefaults Keys**: Not scoped by userId, allowing data leakage
- **Singleton Caches**: Not cleared on sign-out, causing guest/sign-in bug
- **Migration State**: Not user-scoped, affecting all users

### 4. Business Data in UserDefaults
- **Habit Data**: Complete habit definitions stored in UserDefaults
- **XP Data**: User progress, transactions, daily awards in UserDefaults
- **Migration State**: Business logic state in UserDefaults

## Migration Requirements

### Must Migrate to SwiftData:
1. `"SavedHabits"` → SwiftData `HabitData` model
2. `"user_progress"` → SwiftData `UserProgress` model
3. `"recent_xp_transactions"` → SwiftData transaction model
4. `"daily_xp_awards"` → SwiftData `DailyAward` model
5. All migration state keys → SwiftData migration tracking

### Must Clear on Sign-out:
1. `XPManager.shared` singleton cache
2. `HabitRepository.shared` singleton cache
3. `HabitStorageManager.shared` singleton cache
4. `HabitStore.shared` actor cache

### Must Add User Scoping:
1. All UserDefaults keys should be prefixed with userId
2. All singleton caches should be user-scoped
3. Migration state should be tracked per user

## Recommendations

1. **Complete Migration**: Move all business data from UserDefaults to SwiftData
2. **Clear Singletons**: Implement proper cache clearing on authentication state changes
3. **User Scoping**: Add userId prefix to all storage keys
4. **Single Source of Truth**: Use only SwiftData for business data
5. **Cache Management**: Implement proper cache invalidation and user isolation
