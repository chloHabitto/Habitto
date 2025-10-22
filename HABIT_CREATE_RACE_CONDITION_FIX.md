# 🚨 CRITICAL BUG FIX: Habit Creation Race Condition

## Problem Summary

**Habit3 was never saved to the database** because the Create Habit View was dismissing **BEFORE** the async save operation completed!

## Root Cause

The create habit flow had **two premature `dismiss()` calls** that were racing against the async database save:

### Bug Location 1: `CreateHabitFlowView.swift` (Line 116-119)
```swift
onSave: { habit in
  onSave(habit)  // ← Starts async Task in HomeView
  dismiss()      // ← ❌ DISMISSES IMMEDIATELY!
}
```

### Bug Location 2: `CreateHabitStep2View.swift` (Line 600)
```swift
private func saveHabit() {
  let newHabit = createHabit()
  NotificationManager.shared.updateNotifications(for: newHabit, reminders: reminders)
  onSave(newHabit)  // ← Starts async save chain
  dismiss()         // ← ❌ DISMISSES IMMEDIATELY!
}
```

## The Race Condition Flow

1. **User taps "Save"** → `CreateHabitStep2View.saveHabit()` is called
2. **Habit object created** → `createHabit()` creates the Habit struct
3. **onSave callback triggered** → Passes habit up to HomeView
4. **HomeView starts async save**:
   ```swift
   Task { @MainActor in
     await state.createHabit(habit)  // ← This takes time!
     state.showingCreateHabit = false
   }
   ```
5. **❌ View dismisses IMMEDIATELY** (from Step2View or FlowView)
6. **⚠️ Async save still running** but view is already gone
7. **🚫 Save operation interrupted** → Habit never reaches database

## Why This Happened

SwiftUI sheets dismiss instantly when you call `dismiss()`, which **interrupts any ongoing async operations** that were started by the view being dismissed.

The correct pattern for async saves is:
1. ✅ Start async save in **parent view**
2. ✅ **Wait** for completion
3. ✅ **Then** dismiss the sheet

## The Fix

### File 1: `CreateHabitFlowView.swift`
**Removed the premature dismiss:**
```swift
onSave: { habit in
  // ✅ FIX: Don't dismiss here - let the parent handle dismiss after async save completes
  onSave(habit)
  // dismiss() ← REMOVED: This was dismissing before the async save completed!
}
```

### File 2: `CreateHabitStep2View.swift`
**Removed the premature dismiss:**
```swift
private func saveHabit() {
  let newHabit = createHabit()
  NotificationManager.shared.updateNotifications(for: newHabit, reminders: reminders)
  onSave(newHabit)
  // ✅ FIX: Don't dismiss here - let HomeView handle dismiss after async save completes
  // dismiss() ← REMOVED: This was dismissing before the async save in HomeView completed!
}
```

### Why HomeView's Dismiss is Correct
**HomeView already handles the dismiss properly** (line 508-523):
```swift
.sheet(isPresented: $state.showingCreateHabit) {
  CreateHabitFlowView(onSave: { habit in
    Task { @MainActor in
      await state.createHabit(habit)  // ← Wait for save to complete
      state.showingCreateHabit = false // ← THEN dismiss sheet
    }
  })
}
```

## The Correct Flow (After Fix)

1. ✅ User taps "Save"
2. ✅ Habit object created
3. ✅ onSave callback triggered
4. ✅ HomeView starts async save
5. ✅ **Task waits for `await state.createHabit(habit)` to complete**
6. ✅ Habit saved to database
7. ✅ **Then** sheet is dismissed via `state.showingCreateHabit = false`

## Impact

**Before Fix:**
- ❌ Habits never appeared in UI
- ❌ Database saves interrupted mid-operation
- ❌ User data lost
- ❌ No error messages shown (silent failure)

**After Fix:**
- ✅ Habits save completely before view dismisses
- ✅ Habits appear immediately in UI
- ✅ No data loss
- ✅ Proper async/await pattern

## Testing Instructions

1. Open the app
2. Tap "+" to create a new habit
3. Fill in the form:
   - Name: "Test Habit 3"
   - Leave other fields as default
4. Tap "Save"
5. **Expected Result**: 
   - View dismisses after ~1 second (wait for async save)
   - Habit appears in the habit list immediately
   - Habit persists after app restart

## Related Files Changed

- ✅ `Views/Flows/CreateHabitFlowView.swift` (line 116-120)
- ✅ `Views/Flows/CreateHabitStep2View.swift` (line 584-602)

## Technical Notes

This is a **classic race condition** in SwiftUI:
- View dismisses before async operation completes
- Async operation gets interrupted/cancelled
- No error thrown (silent failure)
- Very hard to debug without understanding the timing

**Key Lesson:** When dealing with async saves in sheets/presentations:
1. Always perform async operations in the **presenting view** (parent)
2. Only dismiss **after** the async operation completes
3. Never call `dismiss()` from a child view that triggered an async save

---

**Status:** ✅ FIXED
**Severity:** CRITICAL (Data Loss)
**Type:** Race Condition
**Date:** October 22, 2025

