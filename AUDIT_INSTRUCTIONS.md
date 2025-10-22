# 🔍 DATA ARCHITECTURE AUDIT - INSTRUCTIONS

## 🚨 CRITICAL: Do This BEFORE Any Fixes

**You now have 2 new debug buttons in More → Debug XP Sync section:**

1. **📊 Audit SwiftData** - Checks what's actually in local storage
2. **📊 Audit UserDefaults** - Checks what's in UserDefaults cache

---

## 📋 Step-by-Step Testing Instructions

### Step 1: Run the Audit Buttons

1. **Build and run the app**
2. **Navigate to:** More Tab → Debug XP Sync section
3. **Tap:** "📊 Audit SwiftData"
4. **Copy the console output** (everything from `========== SWIFTDATA AUDIT ==========` to the end)
5. **Tap:** "📊 Audit UserDefaults"
6. **Copy the console output**

### Step 2: Check Firestore Console

1. **Open Firebase Console:** https://console.firebase.google.com
2. **Go to:** Firestore Database
3. **Navigate to:** `users/{your-uid}/habits/`
4. **For EACH habit document:**
   - Click on the document
   - Take a screenshot or note:
     - `name`
     - `completionStatus` (the whole dictionary)
     - `completionHistory` (the whole dictionary)
     - `baseline` / `target`

5. **Navigate to:** `users/{your-uid}/progress/current`
   - Note the `totalXP` value

### Step 3: Report Back

**Paste the following in your response:**

```
## SWIFTDATA AUDIT RESULTS
[paste console output here]

## USERDEFAULTS AUDIT RESULTS
[paste console output here]

## FIRESTORE DATA
Habit1 (Firebase):
  - completionStatus: {...}
  - completionHistory: {...}
  
Habit2 (Firebase):
  - completionStatus: {...}
  - completionHistory: {...}

Progress (Firebase):
  - totalXP: [value]

## CURRENT UI STATE
- Habit1: [complete/incomplete]
- Habit2: [complete/incomplete]
- Streak: [value]
- XP: [value]
```

---

## 🎯 What the Audit Will Prove

Based on the forensic analysis in `DATA_ARCHITECTURE_AUDIT.md`, the audit will likely show:

### Expected SwiftData Results:
- ✅ **2 HabitData** objects (Habit1, Habit2)
- ✅ **CompletionRecords** exist for your completions
- ❌ **BUT:** HabitData doesn't store `completionStatus` dictionary

### Expected UserDefaults Results:
- ✅ **totalXP_[userId]** = [some value]
- ✅ **level_[userId]** = [some value]

### Expected Firestore Results:
- Either:
  - ❌ **Empty completionStatus** (sync didn't complete before rebuild)
  - ✅ **Has completionStatus** (sync completed but old data)

### The Smoking Gun:

**When you load from SwiftData:**
```swift
// HabitDataModel.swift:toHabit()
completionStatus: [:],  // ← ALWAYS EMPTY!
```

**This explains:**
- ❌ Habits appear incomplete (empty completionStatus)
- ❌ Streak = 0 (no completion data found)
- ❌ XP mismatch (Firestore overwrites UserDefaults)

---

## 🚨 DO NOT FIX YET

**Please run the audit and report results first.**

This will **PROVE** the root cause identified in `DATA_ARCHITECTURE_AUDIT.md` and inform the proper architectural fix.

The fix will require:
1. Reconstructing `completionStatus` dictionary from `CompletionRecord` objects when loading from SwiftData
2. Implementing proper merge logic for local + cloud data
3. Fixing the load priority (local-first for recent changes)

**But first, we need PROOF from the audit!**

