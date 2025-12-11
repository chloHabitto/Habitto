# SwiftData @Query Refresh Fix After Guest-to-Authenticated Migration

## Problem

When a user signs in and migrates guest data (userId changes from `""` to authenticated Firebase userId), SwiftData queries don't automatically refresh. The data is migrated correctly (verified by app restart showing data), but views don't update immediately.

## Root Cause

1. **Predicate Caching**: SwiftData `@Query` predicates cache results based on the predicate values. When `userId` changes from `""` to authenticated userId, the predicate doesn't automatically re-evaluate.

2. **ModelContext Pending Changes**: After migration, changes are saved to ModelContext, but queries might execute before pending changes are processed.

3. **Non-Reactive userId**: `CurrentUser().idOrGuest` is async but not observable. Views using it in predicates don't automatically update when userId changes.

## Solution

### 1. Force ModelContext Refresh After Migration

**File**: `Core/Data/HabitRepository.swift`

Added `forceModelContextRefresh()` method that:
- Forces `ModelContext.save()` to process pending changes
- Ensures migrated data is visible to queries
- Logs the refresh process for debugging

```swift
private func forceModelContextRefresh() async {
  await MainActor.run {
    let modelContext = SwiftDataContainer.shared.modelContext
    try? modelContext.save() // Process pending changes
  }
}
```

### 2. Post Notification to Trigger View Refresh

**Files**: 
- `Core/Data/HabitRepository.swift`
- `Core/Data/Migration/GuestToAuthMigration.swift`

Added `userDataMigrated` notification that:
- Is posted after migration completes
- Triggers any `@Query` views to re-evaluate their predicates
- Ensures views see the updated userId

```swift
extension Notification.Name {
  static let userDataMigrated = Notification.Name("userDataMigrated")
}
```

### 3. Ensure Fresh userId in Queries

**File**: `Core/Data/SwiftData/SwiftDataStorage.swift`

Modified `loadHabits()` to:
- Always get fresh userId (never cache)
- Process pending changes before querying
- Log query execution for debugging

```swift
// Always get fresh userId - never cache it
var currentUserId = await getCurrentUserId()

// Process pending changes before fetching
try container.modelContext.save()

var habitDataArray = try container.modelContext.fetch(descriptor)
```

### 4. Comprehensive Logging

Added timestamped logging throughout the migration flow:
- Migration start/completion
- ModelContext refresh
- Query execution with userId
- Verification of loaded data

This helps diagnose any remaining issues.

## Implementation Details

### Migration Completion Flow

1. **GuestDataMigration.migrateGuestData()** completes
2. **GuestToAuthMigration.migrateGuestDataIfNeeded()** migrates data
3. **ModelContext.save()** persists changes
4. **userDataMigrated notification** posted
5. **HabitRepository.handleMigrationCompleted()** called
6. **forceModelContextRefresh()** ensures pending changes are processed
7. **loadHabits(force: true)** re-queries with new userId
8. **objectWillChange.send()** triggers UI update

### Query Refresh Mechanism

When `userId` changes:
1. Migration updates all `userId` fields in SwiftData
2. `ModelContext.save()` persists changes
3. `loadHabits()` gets fresh userId and re-queries
4. Predicate uses new userId value
5. Query returns migrated habits
6. `@Published` property updates
7. Views refresh automatically

## Testing

To verify the fix works:

1. **Start in guest mode** (userId = "")
2. **Create habits and complete them**
3. **Sign in with Apple account**
4. **Click "Keep my data"**
5. **Verify habits appear immediately** (no app restart needed)

### Expected Log Output

```
🔄 [MIGRATION] <timestamp> handleMigrationCompleted() - START
🔄 [MIGRATION] <timestamp> Forcing ModelContext refresh...
🔄 [MODEL_CONTEXT] <timestamp> ModelContext.save() completed
🔄 [MIGRATION] <timestamp> Starting loadHabits(force: true)...
🔄 [SWIFTDATA_QUERY] <timestamp> loadHabits() called - currentUserId: 'abc12345...'
🔄 [SWIFTDATA_QUERY] <timestamp> Query executed - found 3 habits
🔄 [MIGRATION] <timestamp> Posted userDataMigrated notification
🔄 [MIGRATION] <timestamp> objectWillChange.send() called
✅ [MIGRATION] <timestamp> handleMigrationCompleted() - COMPLETE
```

## Notes

- The app primarily uses `HabitRepository.habits` (@Published) rather than direct `@Query`
- The fix ensures `HabitRepository.loadHabits()` uses the current userId
- Views observing `HabitRepository.habits` will automatically update
- If any views use `@Query` directly, they should observe `.userDataMigrated` notification

## Future Improvements

1. Make `CurrentUser` observable so predicates automatically update
2. Add SwiftData query invalidation API when available
3. Consider using `@Query` with dynamic predicates that observe userId changes
