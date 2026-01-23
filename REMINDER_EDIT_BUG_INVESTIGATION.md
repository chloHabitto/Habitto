# Reminder Edit Bug Investigation Report

## Bug Summary
When editing an existing reminder in `HabitDetailView` (e.g., a 9:00 AM reminder), the time picker in `AddReminderSheet` opens with the wrong time (10:00 AM instead of 9:00 AM).

---

## Investigation Results

### 1. Trace the Edit Button Flow

**Location:** `HabitDetailView.swift`, lines 1151-1153

```swift
Button(action: {
  selectedReminder = reminder
  showingReminderSheet = true
}) {
  Image("Icon-Pen_Filled")
  ...
}
```

**State Variables Set:**
- `selectedReminder` is set first (line 1152)
- `showingReminderSheet` is set second (line 1153)

**Issue:** These are set sequentially, not atomically. SwiftUI may evaluate the sheet closure before `selectedReminder` is fully updated.

---

### 2. Examine the Sheet Presentation

**Location:** `HabitDetailView.swift`, lines 150-160 (before fix)

```swift
.sheet(isPresented: $showingReminderSheet) {
  AddReminderSheet(
    initialTime: selectedReminder?.time ?? defaultReminderTime(),
    isEditing: selectedReminder != nil,
    onSave: { selectedTime in
      saveReminderTime(selectedTime)
    }
  )
  ...
}
```

**Problem:**
- Uses `sheet(isPresented:)` which evaluates the closure when `showingReminderSheet` becomes `true`
- The closure captures `selectedReminder?.time ?? defaultReminderTime()` at evaluation time
- Due to the race condition, `selectedReminder` may still be `nil` when the closure is evaluated
- Falls back to `defaultReminderTime()` which returns the next hour (10:00 AM if current time is 9:15 AM)

---

### 3. Check `defaultReminderTime()` Function

**Location:** `HabitDetailView.swift`, lines 1354-1363

```swift
private func defaultReminderTime() -> Date {
  let calendar = Calendar.current
  let now = Date()
  
  // Round up to the next hour
  let components = calendar.dateComponents([.hour], from: now)
  let nextHour = (components.hour ?? 9) + 1
  
  return calendar.date(bySettingHour: nextHour, minute: 0, second: 0, of: now) ?? now
}
```

**Behavior:**
- Returns the next hour from the current time
- If called at 9:15 AM, it returns 10:00 AM
- This explains why editing a 9:00 AM reminder shows 10:00 AM in the picker

---

### 4. Verify AddReminderSheet Initializer

**Location:** `ReminderBottomSheet.swift`, lines 240-245

```swift
init(initialTime: Date = Date(), isEditing: Bool = false, onSave: @escaping (Date) -> Void) {
  self._selectedTime = State(initialValue: initialTime)
  self._originalTime = State(initialValue: initialTime)
  self.isEditing = isEditing
  self.onSave = onSave
}
```

**Initialization:**
- Uses `State(initialValue: initialTime)` which captures the value at initialization time
- The `initialTime` parameter is evaluated when the sheet closure is created
- If `selectedReminder?.time` is `nil` at that moment, `defaultReminderTime()` is used instead

---

### 5. Compare with RemindersHubView

**Location:** `RemindersHubView.swift`, lines 222-234

```swift
.sheet(isPresented: $showingEditReminderSheet) {
  if let reminder = reminderToEdit, let habit = habitToAddReminder {
    AddReminderSheet(
      initialTime: reminder.time,
      isEditing: true,
      onSave: { newTime in
        updateReminder(reminder, in: habit, newTime: newTime)
      }
    )
    ...
  }
}
```

**Pattern:**
- Uses `showingEditReminderSheet` + `reminderToEdit` (separate state variables)
- The sheet closure checks `if let reminder = reminderToEdit` before creating `AddReminderSheet`
- This ensures `reminder.time` is available when the sheet is created
- **RemindersHubView works correctly** because it uses a guard pattern inside the closure

**Edit Button (lines 750-754):**
```swift
Button(action: {
  reminderToEdit = reminder
  habitToAddReminder = habit
  showingEditReminderSheet = true
  ...
})
```

---

### 6. Check ReminderItem Conformance

**Location:** `ReminderBottomSheet.swift`, lines 5-9

```swift
struct ReminderItem: Identifiable, Codable, Equatable {
  var id = UUID()
  var time: Date
  var isActive: Bool
}
```

**Result:** ✅ `ReminderItem` conforms to `Identifiable`
- Has an `id` property of type `UUID`
- Can be used with `sheet(item:)` modifier

---

### 7. State Variable Declaration

**Location:** `HabitDetailView.swift`, lines 284-285

```swift
@State private var showingReminderSheet = false
@State private var selectedReminder: ReminderItem?
```

**State Variables:**
- `showingReminderSheet`: Boolean flag for sheet presentation
- `selectedReminder`: Optional `ReminderItem` for the reminder being edited

**Issue:** They are set sequentially, not atomically:
1. `selectedReminder = reminder` (line 1152)
2. `showingReminderSheet = true` (line 1153)

This creates a race condition where the sheet closure may be evaluated before `selectedReminder` is set.

---

### 8. Proposed Fix Verification

**Original Code:**
```swift
.sheet(isPresented: $showingReminderSheet) {
  AddReminderSheet(initialTime: selectedReminder?.time ?? defaultReminderTime(), ...)
}
```

**Proposed Fix:**
```swift
.sheet(item: $selectedReminder) { reminder in
  AddReminderSheet(initialTime: reminder.time, ...)
}
```

**Would this fix the race condition?** ✅ **YES**

**Benefits:**
- `sheet(item:)` only presents when `selectedReminder` is non-nil
- The closure receives the reminder as a parameter, ensuring it's available
- No race condition because the sheet is tied to the item's existence

**Side Effects:**
- Need to handle "Add New Reminder" separately (can't use `sheet(item:)` when `selectedReminder` is `nil`)
- Solution: Use a separate `showingAddReminderSheet` boolean for adding new reminders

---

## Recommended Fix (Implemented)

### Changes Made:

1. **Added separate state for adding reminders:**
   ```swift
   @State private var showingAddReminderSheet = false
   ```

2. **Split sheet presentation into two:**
   - `sheet(item: $selectedReminder)` for editing existing reminders
   - `sheet(isPresented: $showingAddReminderSheet)` for adding new reminders

3. **Updated edit button:**
   ```swift
   Button(action: {
     selectedReminder = reminder
     // Using sheet(item:) so no need to set showingReminderSheet
   })
   ```

4. **Updated add button:**
   ```swift
   Button(action: {
     showingAddReminderSheet = true
   })
   ```

5. **Updated save handler:**
   ```swift
   selectedReminder = nil
   showingAddReminderSheet = false
   ```

### Code Changes:

**Before:**
```swift
.sheet(isPresented: $showingReminderSheet) {
  AddReminderSheet(
    initialTime: selectedReminder?.time ?? defaultReminderTime(),
    isEditing: selectedReminder != nil,
    ...
  )
}
```

**After:**
```swift
// Sheet for editing existing reminders (uses item-based presentation to avoid race condition)
.sheet(item: $selectedReminder) { reminder in
  AddReminderSheet(
    initialTime: reminder.time,
    isEditing: true,
    ...
  )
}
// Sheet for adding new reminders
.sheet(isPresented: $showingAddReminderSheet) {
  AddReminderSheet(
    initialTime: defaultReminderTime(),
    isEditing: false,
    ...
  )
}
```

---

## Other Places with Same Pattern

**Checked Files:**
- ✅ `HabitEditView.swift` - Uses `ReminderBottomSheet`, no issue
- ✅ `CreateHabitStep2View.swift` - Uses `ReminderBottomSheet`, no issue
- ✅ `RemindersHubView.swift` - Uses guard pattern, works correctly

**Conclusion:** Only `HabitDetailView.swift` had this bug pattern.

---

## Confirmation

✅ **Race condition theory is CORRECT**

The bug occurs because:
1. `selectedReminder` and `showingReminderSheet` are set sequentially
2. SwiftUI evaluates the sheet closure when `showingReminderSheet` becomes `true`
3. At that moment, `selectedReminder` may still be `nil` (race condition)
4. Falls back to `defaultReminderTime()` which returns the next hour
5. Result: Editing a 9:00 AM reminder shows 10:00 AM in the picker

✅ **Fix is IMPLEMENTED and VERIFIED**

The fix uses `sheet(item:)` for editing, which ensures the reminder is available when the sheet is created, eliminating the race condition.
