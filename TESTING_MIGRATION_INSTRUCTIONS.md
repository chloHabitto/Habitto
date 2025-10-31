# Testing Migration - Step by Step Guide

## ⚠️ Important: Authentication State

**Quick Answer**: Test while **signed in** (your current state: `chloe9609@gmail.com`) using `force: true` - this matches production behavior.

**You can test migration in either mode, but behavior differs:**

### Option 1: Signed In Mode ✅ (Recommended - Your Current State)
- **Current situation**: You're signed in as `chloe9609@gmail.com`
- **Why**: Tests the real-world scenario where users have existing data
- **Behavior**: Migration guard prevents auto-migration (expects UI to handle it)
- **Solution**: Use `force: true` to bypass the guard (shown in Step 2)
- **User ID**: Your habits will be saved with ID `mMl83AlWhhfT7NpyHCTY1SZuTq93`

### Option 2: Guest Mode
- **Use case**: Testing migration for new/guest users
- **Behavior**: Migration may run automatically if no guard is triggered
- **Note**: Still works with `force: true` if auto-migration is blocked
- **User ID**: Habits will be saved with ID `"guest"`

**Recommendation**: Test while **signed in** (your current state) to match production behavior.

## Issue Summary
The app is finding 2 habits in UserDefaults (`SavedHabits`) but not loading them because:
- User is authenticated (`chloe9609@gmail.com`)
- Guest data exists
- The migration guard prevents auto-migration (expects UI to handle it)

## Solution: Use MigrationTestHelper

### Step 1: Check Current Status

**⚠️ Important**: Xcode's LLDB debugger doesn't handle async Swift code well. Use one of these methods:

#### **Method 1: Use Debug Buttons in the App (Easiest)** ✅ **RECOMMENDED**

1. **Run your app** (press `Cmd+R`)
2. **Navigate to**: More Tab → Scroll to Debug section
3. **You'll see three new buttons**:
   - **🔍 Check Migration Status** - View current migration state
   - **🚀 Trigger Migration (Force)** - Run the migration
   - **✅ Verify Migration** - Check if migration worked correctly
4. **Tap each button** and check the **Xcode Console** (bottom panel) for output

**This is the easiest way** - no need to type code in the console!

#### **Method 2: Use Xcode Console** (If buttons aren't available)

If you prefer using the console directly, you can add temporary buttons to any view, or use Method 3 below.

#### **Method 3: Use Xcode Console with Expression** (Advanced)

1. **Set a breakpoint** in your app (click in the gutter next to a line of code)
2. **Run the app** (press `Cmd+R`)
3. When the breakpoint hits, **open the Console** (bottom panel)
4. Type this in the console:
   ```
   expression -- async { await MainActor.run { try? await MigrationTestHelper.shared.printMigrationStatus() } }
   ```
   (Note: This may not work reliably - Method 1 or 2 is better)

**Expected output:**
You should see a migration status report in the console showing:
- Migration state (completed/pending)
- Number of ProgressEvents
- Number of completionHistory entries
- Habits with history

### Step 2: Trigger Migration (Force Mode)
**When signed in**: Use `force: true` to bypass the migration guard.  
**When in guest mode**: Can use `force: false` first, but `force: true` always works.

```swift
Task { @MainActor in
    // Check your auth state first (optional)
    let userId = await CurrentUser().idOrGuest
    print("Current User ID: \(userId)")
    
    // Trigger migration (force: true works in both signed in and guest mode)
    try? await MigrationTestHelper.shared.triggerMigration(force: true)
}
```

This will:
1. Load habits from UserDefaults (`SavedHabits`)
2. Save them to SwiftData as `HabitData` with the current user's ID
3. Convert `completionHistory` entries to `ProgressEvent` records
4. Mark events as `synced: false` for SyncEngine to upload

**Note**: When signed in, the habits will be associated with your authenticated user ID (`mMl83AlWhhfT7NpyHCTY1SZuTq93`). In guest mode, they'll be associated with "guest".

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

