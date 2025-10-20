# 🐛 CRITICAL: XP Calculation Bug Fix

## Problem Summary

**XP stays at 0** even though habits are completed and `CompletionRecord`s are being written to SwiftData.

---

## Root Causes

### 1. **XP Calculation Uses OLD Data**
**File:** `Views/Tabs/HomeTabView.swift:1066-1103`

```swift
private func countCompletedDays() -> Int {
  // ...
  let allCompleted = !habitsForDate.isEmpty && habitsForDate.allSatisfy { 
    $0.isCompleted(for: currentDate)  // ❌ BUG: Reads from OLD completionHistory!
  }
  // ...
}
```

**THE ISSUE:**
- `Habit.isCompleted(for:)` reads from `completionHistory`/`completionStatus` dictionaries
- But **CompletionRecords are being written to SwiftData**, not those dictionaries!
- Result: XP calculation sees 0 completed days even though CompletionRecords exist

### 2. **Breaking Habit Has Invalid Data**
**Validation Error in Console:**
```
❌ DataError: Target must be less than baseline for habit breaking
   - habits[0].target: Target must be less than baseline for habit breaking (severity: error)
Non-critical validation errors found, proceeding with save  ← BAD!
```

**THE ISSUE:**
- Habit2 (breaking habit) has `target >= baseline` (invalid!)
- Validation logs the error but **allows save anyway**
- This corrupts the completion logic

### 3. **isCompleted Doesn't Check CompletionRecords**
**File:** `Core/Models/Habit.swift:633-663`

```swift
private func isCompletedInternal(for date: Date) -> Bool {
  let dateKey = Self.dateKey(for: date)
  
  // First check the new boolean completion status
  if let completionStatus = completionStatus[dateKey] {
    return completionStatus  // ❌ OLD DATA!
  }
  
  // Fallback to old system
  if habitType == .breaking {
    let usage = actualUsage[dateKey] ?? 0
    return usage <= target  // ❌ OLD DATA + BUG with invalid target!
  }
  // ...
}
```

**THE ISSUE:**
- Never queries `CompletionRecord` from SwiftData
- Still relies on OLD dictionaries

---

## Solutions

### **Solution 1: Query CompletionRecords in countCompletedDays()**

Replace the XP calculation to read from SwiftData:

```swift
@MainActor
private func countCompletedDays() -> Int {
  guard let userId = AuthenticationManager.shared.currentUser?.uid else { return 0 }
  guard !habits.isEmpty else { return 0 }
  
  let calendar = Calendar.current
  let today = LegacyDateUtils.today()
  
  // Find the earliest habit start date
  guard let earliestStartDate = habits.map({ $0.startDate }).min() else { return 0 }
  let startDate = DateUtils.startOfDay(for: earliestStartDate)
  
  var completedCount = 0
  var currentDate = startDate
  
  // ✅ FIX: Get ModelContext for querying CompletionRecords
  let modelContext = SwiftDataContainer.shared.modelContext
  
  // Count all days where all habits are completed
  while currentDate <= today {
    let dateKey = Habit.dateKey(for: currentDate)
    
    let habitsForDate = habits.filter { habit in
      let selected = DateUtils.startOfDay(for: currentDate)
      let start = DateUtils.startOfDay(for: habit.startDate)
      let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
      
      guard selected >= start, selected <= end else { return false }
      return shouldShowHabitOnDate(habit, date: currentDate)
    }
    
    // ✅ FIX: Check CompletionRecords instead of old completionHistory!
    let allCompleted = !habitsForDate.isEmpty && habitsForDate.allSatisfy { habit in
      // Query SwiftData for this habit's completion on this date
      let predicate = #Predicate<CompletionRecord> { record in
        record.habitId == habit.id && record.dateKey == dateKey && record.completed == true
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      
      do {
        let records = try modelContext.fetch(descriptor)
        return !records.isEmpty  // Complete if CompletionRecord exists with completed=true
      } catch {
        print("❌ XP_CALC: Failed to query CompletionRecord for \(habit.name): \(error)")
        return false
      }
    }
    
    if allCompleted {
      completedCount += 1
    }
    
    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
    currentDate = nextDate
  }
  
  return completedCount
}
```

### **Solution 2: Fix Breaking Habit Validation**

Make validation FAIL HARD on invalid data:

**Find validation code and change:**
```swift
// BEFORE:
Non-critical validation errors found, proceeding with save

// AFTER:
throw ValidationError.invalidBreakingHabitTarget("Target must be less than baseline")
```

### **Solution 3: Update isCompleted to Check CompletionRecords**

**File:** `Core/Models/Habit.swift:633-663`

Add SwiftData query:

```swift
private func isCompletedInternal(for date: Date) -> Bool {
  let dateKey = Self.dateKey(for: date)
  
  // ✅ FIX: Check CompletionRecords in SwiftData FIRST
  let modelContext = SwiftDataContainer.shared.modelContext
  let predicate = #Predicate<CompletionRecord> { record in
    record.habitId == self.id && record.dateKey == dateKey && record.completed == true
  }
  let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
  
  do {
    let records = try modelContext.fetch(descriptor)
    if !records.isEmpty {
      return true  // Found CompletionRecord with completed=true
    }
  } catch {
    print("❌ isCompleted: Failed to query CompletionRecord: \(error)")
  }
  
  // Fallback to old system for migration purposes
  if let completionStatus = completionStatus[dateKey] {
    return completionStatus
  }
  
  if habitType == .breaking {
    let usage = actualUsage[dateKey] ?? 0
    return usage <= target
  } else {
    let progress = completionHistory[dateKey] ?? 0
    if let targetAmount = parseGoalAmount(from: goal) {
      return progress >= targetAmount
    }
    return progress > 0
  }
}
```

---

## Priority

1. **HIGHEST:** Fix `countCompletedDays()` to query CompletionRecords ✅
2. **HIGH:** Fix breaking habit validation ⚠️
3. **MEDIUM:** Update `isCompleted()` to check CompletionRecords ℹ️

---

## Testing

After applying fixes:

1. Reset habits (mark both incomplete)
2. Complete Habit1 → Check console for `✅ DERIVED_XP: XP set to 0` (should still be 0, 1 habit remaining)
3. Complete Habit2 → Check console for `✅ DERIVED_XP: XP set to 50` (should be 50 now!)
4. Verify celebration triggers
5. Check More tab → Should show 50 XP

---

## Status

- [x] Root causes identified
- [ ] Fix 1 implemented (countCompletedDays)
- [ ] Fix 2 implemented (validation)
- [ ] Fix 3 implemented (isCompleted)
- [ ] Tested and verified

