# Testing Migration - Step by Step Guide

## ⚠️ CRITICAL: Authentication State - Read This First!

### **Which Mode Should I Use?**

**✅ ANSWER: Test while SIGNED IN** (this matches production behavior)

### **Why?**

The app has a **migration guard** that prevents auto-migration when:
- ✅ User is **signed in** (authenticated)
- ✅ Guest data exists in UserDefaults

**This guard is by design** - it prevents silent migrations and expects the UI to handle migration explicitly.

### **What This Means:**

| Mode | Auto-Migration? | Manual Migration? | Recommendation |
|------|----------------|-------------------|----------------|
| **Signed In** (e.g., `chloe9609@gmail.com`) | ❌ **Blocked** by guard | ✅ **Works** with `force: true` | ✅ **Use this** - matches production |
| **Guest Mode** | ✅ May work | ✅ Always works | ⚠️ Less realistic |

### **Your Current Situation:**

Based on your console output:
- ✅ You're **signed in** as `chloe9609@gmail.com` (UID: `mMl83AlWhhfT7NpyHCTY1SZuTq93`)
- ✅ You have **2 legacy habits** in UserDefaults (`SavedHabits`)
- ✅ Auto-migration is **blocked** (as expected)
- ✅ **Solution**: Use the debug buttons with `force: true` (they do this automatically)

### **Bottom Line:**

**Just use the debug buttons** - they handle everything automatically, regardless of auth state!

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

**If you already clicked "Check Migration Status":**
- ✅ You've completed Step 1!
- ➡️ **Next**: Go to Step 2 below

### Step 2: Trigger Migration

**🎯 Goal**: Convert your existing `completionHistory` entries into `ProgressEvent` records.

**Quick Action**:
1. In the app, tap the **"🚀 Trigger Migration (Force)"** button
2. Watch the **Xcode Console** for progress logs
3. Look for messages like:
   - `✅ MigrationRunner: Migrated X completionHistory entries to ProgressEvent records`
   - `✅ MigrationRunner: Migration completed successfully`

**If using debug buttons** (recommended): Just tap **"🚀 Trigger Migration (Force)"** - it automatically uses `force: true`.

**If using console** (advanced): Use `force: true` - it works in both signed-in and guest mode.

```swift
Task { @MainActor in
    // Trigger migration (force: true bypasses all guards)
    try? await MigrationTestHelper.shared.triggerMigration(force: true)
}
```

**What happens:**
1. ✅ Loads habits from UserDefaults (`SavedHabits`)
2. ✅ Saves them to SwiftData as `HabitData` with your current user ID
3. ✅ Converts `completionHistory` entries to `ProgressEvent` records
4. ✅ Marks events as `synced: false` (SyncEngine will upload them later)

**Important Notes:**
- **Signed in**: Habits saved with your authenticated user ID (e.g., `mMl83AlWhhfT7NpyHCTY1SZuTq93`)
- **Guest mode**: Habits saved with user ID `"guest"`
- **`force: true`**: Bypasses the migration guard and `isCompleted` check - safe to use anytime

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

