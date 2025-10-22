# Fix Habit2 in Firestore

## Problem
Habit2 in Firestore has `baseline: 0` which makes it invalid and gets filtered out.

## Solution: Manually Update Firestore

### Option 1: Use Firebase Console (Quickest)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Firestore Database
3. Navigate to: `users/otiTS5d5wOcdQYVWBiwF3dKBFzJ2/habits`
4. Find Habit2 (the breaking habit)
5. Click "Edit"
6. Update these fields:
   - `baseline`: 20 (not 0!)
   - `target`: 10
7. Click "Update"
8. **Restart the app**
9. Habit2 should appear!

---

### Option 2: Add Debug Button to Fix It

I can add a button that:
1. Finds Habit2 in Firestore
2. Updates baseline to 20
3. Reloads habits

Would you like me to implement this?

