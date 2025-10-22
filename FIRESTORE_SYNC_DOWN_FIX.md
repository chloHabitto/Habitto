# Firestore Sync-Down Fix

## Problem

After deleting and reinstalling the app:
- ❌ Local SwiftData database is empty
- ✅ Firestore still has all 5 habits
- ❌ App shows no habits (doesn't sync down from Firestore)

## Root Cause

The app uses a "local-first" architecture:
- **Writes**: Save to local SwiftData → Background sync to Firestore ✓
- **Reads**: Only load from local SwiftData ❌

There was **no sync-down mechanism** to pull habits from Firestore when the local database is empty.

## The Fix

I added automatic Firestore sync-down in `DualWriteStorage.loadHabits()`:

```swift
func loadHabits() async throws -> [Habit] {
  // Load from local SwiftData
  let habits = try await secondaryStorage.loadHabits()
  
  // ✅ NEW: If local storage is empty, sync from Firestore
  if filtered.isEmpty {
    print("📂 Local storage empty, syncing from Firestore...")
    
    // Fetch from Firestore
    try await primaryStorage.fetchHabits()
    let firestoreHabits = await MainActor.run { primaryStorage.habits }
    
    if !firestoreHabits.isEmpty {
      print("📥 Found \(firestoreHabits.count) habits in Firestore")
      
      // Save to local storage
      try await secondaryStorage.saveHabits(firestoreHabits, immediate: true)
      
      print("✅ Successfully synced from Firestore")
      return firestoreHabits
    }
  }
  
  return filtered
}
```

### How It Works

1. **Normal Case** (local data exists):
   - Load from local SwiftData
   - Return habits immediately
   - Fast & offline-capable ✓

2. **Fresh Install** (local data empty):
   - Detect empty local storage
   - Fetch from Firestore
   - Save to local SwiftData
   - Return synced habits
   - User sees their data restored ✓

3. **Network Failure**:
   - If Firestore fetch fails, return empty array
   - App won't crash, just shows empty state
   - User can try again or create new habits

## Files Modified

- **Core/Data/Storage/DualWriteStorage.swift** - Added sync-down logic to `loadHabits()`

## Testing Instructions

### Test 1: Fresh Install Data Recovery

1. **Delete the app** from your device/simulator
2. **Verify Firestore has data:**
   - Open Firebase Console
   - Navigate to Firestore Database
   - Check `/users/{userId}/habits/` collection
   - Should see 5 habit documents

3. **Reinstall and launch the app:**
   - Build and run (⌘R)
   - **IMPORTANT**: Make sure you're signed in with the same account

4. **Expected Result:**
   - ✅ App detects empty local storage
   - ✅ Automatically fetches from Firestore
   - ✅ Saves to local SwiftData
   - ✅ All 5 habits appear in the app
   - ✅ Console shows:
     ```
     📂 LOAD: Local storage is empty, attempting to sync from Firestore...
     📥 SYNC_DOWN: Found 5 habits in Firestore, saving to local...
     ✅ SYNC_DOWN: Successfully synced 5 habits from Firestore
     ```

### Test 2: Normal App Launch (with existing data)

1. **Launch app** normally (don't delete)
2. **Expected Result:**
   - ✅ Loads from local SwiftData instantly
   - ✅ No Firestore fetch (faster)
   - ✅ Console shows:
     ```
     📂 LOAD: Using local-first strategy - loading from SwiftData
     ✅ LOAD: Loaded 5 habits from SwiftData successfully
     ```

### Test 3: Network Failure Handling

1. **Turn off WiFi/Cellular**
2. **Delete and reinstall app**
3. **Launch app**
4. **Expected Result:**
   - ✅ App attempts Firestore sync
   - ⚠️ Sync fails gracefully (no crash)
   - ℹ️ Shows empty state
   - ✅ User can create new habits
   - ✅ Console shows:
     ```
     📂 LOAD: Local storage is empty, attempting to sync from Firestore...
     ⚠️ SYNC_DOWN: Failed to sync from Firestore: [error]
     ```

## Important Notes

### Authentication Required

The sync-down only works if you're **signed in with the same account** that created the habits:
- Firestore habits are stored at `/users/{userId}/habits/`
- Each user has their own isolated data
- If you sign in with a different account, you'll see that account's habits (or empty if new account)

### Guest Mode

If you were using the app in **guest mode** (not signed in):
- Guest data is stored locally only
- Firestore won't have your habits
- Deleting the app will lose guest data permanently
- This is expected behavior for privacy

### First-Time Users

For brand new users:
- Local storage: empty
- Firestore: empty
- Sync-down detects both are empty
- App shows tutorial/onboarding
- No data loss (because there was no data)

## Architecture Benefits

This maintains the **best of both worlds**:

1. **Local-First Performance**:
   - Normal app usage is fast (no network calls)
   - Offline-capable
   - Instant UI updates

2. **Cloud Backup**:
   - Data synced to Firestore in background
   - Survives app deletion
   - Can restore from any device

3. **Automatic Recovery**:
   - Fresh install automatically pulls from cloud
   - No manual "restore backup" step needed
   - Seamless user experience

## Next Steps

After testing:
1. Verify your 5 habits are restored
2. Complete some habits and verify they save
3. Close and reopen app to verify persistence still works
4. The earlier persistence bug fix (progress counts) is still in effect

## Migration Note

This fix is **immediately available** - no schema changes needed. Just rebuild and test!

```bash
# Build and test
Product → Clean Build Folder (⇧⌘K)
Product → Run (⌘R)
```

