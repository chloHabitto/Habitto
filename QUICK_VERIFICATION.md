# Quick Firestore Verification - Phase 1

**Your Firebase UID:** `fQVQZ0ch8uYsR6sSlvxf5BG3iUe2`

---

## 🚀 Fastest Way: Firebase Console (30 seconds)

### Direct Link (Replace PROJECT_ID with your actual project ID):
```
https://console.firebase.google.com/project/YOUR_PROJECT_ID/firestore/data/~2Fusers~2FfQVQZ0ch8uYsR6sSlvxf5BG3iUe2
```

### Manual Steps:
1. Go to: https://console.firebase.google.com/
2. Select your project
3. Click **Firestore Database** in left sidebar
4. Click on **`users`** collection
5. Click on document: **`fQVQZ0ch8uYsR6sSlvxf5BG3iUe2`**

### What to Look For:

**✅ SUCCESS - You should see:**
- Document exists with your UID
- Subcollections visible:
  - `events/` (if you've created/completed habits)
  - `completions/` (if you've completed habits)
  - `daily_awards/` (if you've earned XP)

**❌ FAILURE - If you see:**
- "Document not found"
- No subcollections
- Empty document

---

## 📊 Exact Paths to Check

### Path 1: User Document
```
users/fQVQZ0ch8uYsR6sSlvxf5BG3iUe2
```
**Expected:** Document exists (even if empty, this confirms sync is working)

### Path 2: Events Collection
```
users/fQVQZ0ch8uYsR6sSlvxf5BG3iUe2/events/
```
**Expected:** 
- If you've created/completed habits: Year-month collections (e.g., `2024-11/`)
- If no habits yet: Collection exists but empty (this is OK)

### Path 3: Completions Collection
```
users/fQVQZ0ch8uYsR6sSlvxf5BG3iUe2/completions/
```
**Expected:**
- If you've completed habits: Documents with IDs like `comp_{habitId}_{dateKey}`
- If no completions yet: Collection exists but empty (this is OK)

### Path 4: Daily Awards Collection
```
users/fQVQZ0ch8uYsR6sSlvxf5BG3iUe2/daily_awards/
```
**Expected:**
- If you've earned XP: Documents with IDs like `{userId}#{dateKey}`
- If no XP yet: Collection exists but empty (this is OK)

---

## ✅ Quick Verification Checklist

**Minimum Success Criteria:**
- [ ] Document `users/fQVQZ0ch8uYsR6sSlvxf5BG3iUe2` exists
- [ ] At least one subcollection is visible (events, completions, or daily_awards)

**Full Success Criteria (if you've used the app):**
- [ ] `events/` collection has data (after creating/completing habits)
- [ ] `completions/` collection has data (after completing habits)
- [ ] `daily_awards/` collection has data (after earning XP)

---

## 🔧 Alternative: Command Line (if you have Firebase CLI)

### Option 1: Run the verification script
```bash
./verify_firestore.sh fQVQZ0ch8uYsR6sSlvxf5BG3iUe2
```

### Option 2: Manual Firebase CLI commands
```bash
# Check if user document exists
firebase firestore:get users/fQVQZ0ch8uYsR6sSlvxf5BG3iUe2 --project YOUR_PROJECT_ID

# List events
firebase firestore:get users/fQVQZ0ch8uYsR6sSlvxf5BG3iUe2/events --project YOUR_PROJECT_ID

# List completions
firebase firestore:get users/fQVQZ0ch8uYsR6sSlvxf5BG3iUe2/completions --project YOUR_PROJECT_ID
```

---

## 🎯 What This Confirms

**If you see data in Firestore:**
✅ Anonymous authentication is working  
✅ Sync is running  
✅ Data is being written to Firestore  
✅ Phase 1 is 100% complete  

**If you don't see data yet:**
- Wait 5 minutes (sync interval)
- Create and complete a habit
- Check again

---

## 📝 Notes

- **Empty collections are OK** - They're created when sync runs, even if no data yet
- **Document must exist** - The user document should exist even if empty
- **Data appears within 5 minutes** - After creating/completing habits

---

**Last Updated:** November 22, 2024

