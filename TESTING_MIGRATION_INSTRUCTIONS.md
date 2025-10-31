# Testing Migration - Step by Step Guide

## Issue Summary
The app is finding 2 habits in UserDefaults (`SavedHabits`) but not loading them because:
- User is authenticated (`chloe9609@gmail.com`)
- Guest data exists
- The migration guard prevents auto-migration (expects UI to handle it)

## Solution: Use MigrationTestHelper

### Step 1: Check Current Status
In Xcode's **Debug Console** (LLDB), run:

```swift
Task { @MainActor in
    try? await MigrationTestHelper.shared.printMigrationStatus()
}
```

This will show:
- Migration state (completed/pending)
- Number of ProgressEvents
- Number of completionHistory entries
- Habits with history

### Step 2: Trigger Migration (Force Mode)
Force the migration to bypass guards:

```swift
Task { @MainActor in
    try? await MigrationTestHelper.shared.triggerMigration(force: true)
}
```

This will:
1. Load habits from UserDefaults (`SavedHabits`)
2. Save them to SwiftData as `HabitData`
3. Convert `completionHistory` entries to `ProgressEvent` records
4. Mark events as `synced: false` for SyncEngine to upload

### Step 3: Verify Migration Results
Check if migration was successful:

```swift
Task { @MainActor in
    try? await MigrationTestHelper.shared.printVerification()
}
```

This compares:
- `completionHistory` entries vs `ProgressEvent` records
- Progress values match between legacy and event-sourced data

### Step 4: Reload Habits in UI
After migration, reload habits in the app:

```swift
Task { @MainActor in
    await HabitRepository.shared.loadHabits(force: true)
}
```

### Step 5: Check Final Status
Verify everything worked:

```swift
Task { @MainActor in
    try? await MigrationTestHelper.shared.printMigrationStatus()
}
```

## Expected Results

After migration, you should see:
- ✅ Migration State: `completed`
- ✅ Progress Events: `2` (one for each habit's completion)
- ✅ Events marked with `operationId` starting with `migration_`
- ✅ Habits visible in the UI (after reload)

## Troubleshooting

### If habits still don't show:
1. Check if habits were saved to SwiftData:
   ```swift
   Task { @MainActor in
       let context = SwiftDataContainer.shared.modelContext
       let descriptor = FetchDescriptor<HabitData>()
       let habits = try? context.fetch(descriptor)
       print("Habits in SwiftData: \(habits?.count ?? 0)")
   }
   ```

2. Check the current user ID:
   ```swift
   Task { @MainActor in
       let userId = await CurrentUser().idOrGuest
       print("Current User ID: \(userId)")
   }
   ```

3. Verify habits have correct userId:
   ```swift
   Task { @MainActor in
       let context = SwiftDataContainer.shared.modelContext
       let userId = await CurrentUser().idOrGuest
       let descriptor = FetchDescriptor<HabitData>(
           predicate: #Predicate { $0.userId == userId }
       )
       let habits = try? context.fetch(descriptor)
       print("Habits for user \(userId): \(habits?.count ?? 0)")
   }
   ```

## Notes

- Migration is **idempotent** - safe to run multiple times
- `completionHistory` is **preserved** for rollback safety
- Events are marked `synced: false` so SyncEngine will upload them
- Migration events use deterministic `operationId` for deduplication

