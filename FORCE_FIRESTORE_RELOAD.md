# Force Firestore Reload - Recovery Steps

## Problem
- Habit2 is in Firestore ✅
- App is loading from corrupted SwiftData ❌
- Migration is not marked as complete

## Solution: Force Mark Migration Complete

### Step 1: Add Debug Button to Force Migration Complete

Add this to `MoreTabView.swift` in the DEBUG section:

```swift
Button("🔥 Force Mark Migration Complete") {
  Task {
    await forceMarkMigrationComplete()
  }
}
.buttonStyle(.borderedProminent)
.tint(.orange)

// Add this function:
private func forceMarkMigrationComplete() async {
  guard let userId = AuthenticationManager.shared.currentUser?.uid else {
    print("❌ No user ID")
    return
  }
  
  do {
    let db = Firestore.firestore()
    try await db
      .collection("users")
      .document(userId)
      .collection("meta")
      .document("migration")
      .setData([
        "status": "complete",
        "completedAt": Date(),
        "forcedByUser": true
      ])
    
    print("✅ Migration marked as complete!")
    print("📱 Please restart the app to reload from Firestore")
  } catch {
    print("❌ Failed to mark migration complete: \(error)")
  }
}
```

### Step 2: After Tapping the Button
1. **Restart the app** (force quit and reopen)
2. Habits should now load from Firestore
3. **Habit2 should appear!** 🎉

### Step 3: Verify
Check console for:
```
✅ DualWriteStorage: Loaded 2 habits from Firestore
```

Instead of:
```
⚠️ DualWriteStorage: Migration not complete, using local storage
```

---

## Alternative: Use Firebase Console

1. Go to Firebase Console
2. Firestore Database
3. Navigate to: `users/otiTS5d5wOcdQYVWBiwF3dKBFzJ2/meta`
4. Create a document called `migration`
5. Add field: `status` = `"complete"` (string)
6. Restart the app

---

## Verification

After restarting, check console for these logs:
- ✅ `Migration complete, loading from Firestore`
- ✅ `Loaded 2 habits from Firestore`
- ✅ `Habit2` should be visible in the app

