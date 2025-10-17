# 🏗️ XP System - Architectural Refactor

## ✅ What We've Implemented (Step 1)

### 1. **Single Instance Enforcement** ✅
```swift
// XPManager now fails fast on duplicate instances
private static weak var _instance: XPManager?

init() {
    if let existing = XPManager._instance {
        preconditionFailure("❌ DUPLICATE XPManager INSTANCE!")
    }
    XPManager._instance = self
    print("🏪 STORE_INSTANCE XPManager created: \(ObjectIdentifier(self))")
}
```

**What this does:**
- Crashes immediately if you accidentally create a second XPManager
- Prints instance ID on creation
- Proves single source of truth

### 2. **Derived XP (Pure Function)** ✅
```swift
// NEW: Pure function (no side effects, idempotent)
func recalculateXP(completedDaysCount: Int) -> Int {
    return completedDaysCount * 50
}

// NEW: Single mutation point
@MainActor
func publishXP(completedDaysCount: Int) {
    let newXP = recalculateXP(completedDaysCount: completedDaysCount)
    guard newXP != oldXP else { return }  // Skip if unchanged
    
    print("🔍 XP_SET totalXP:\(newXP) completedDays:\(completedDaysCount)")
    userProgress.totalXP = newXP
    updateLevelFromXP()
}
```

**Invariant:** `xp == 50 * completedDaysCount` (ALWAYS)

---

## 🧪 Test the Fix

### Step 1: Prove Single Instance
Build and run the app, check console for:
```
✅ GOOD: Only one line
🏪 STORE_INSTANCE XPManager created: ObjectIdentifier(0x...)

❌ BAD: Multiple lines (should crash now!)
🏪 STORE_INSTANCE XPManager created: ObjectIdentifier(0x123...)
🏪 STORE_INSTANCE XPManager created: ObjectIdentifier(0x456...)
```

### Step 2: Tab Switching
```
1. Complete all habits for today
2. Switch Home → More → Home (10 times)
3. Check console:
   - Should see NO XP_SET messages
   - XP should stay at 50
```

### Step 3: Historical Edit
```
Day 1: Complete all → XP = 50
Day 2: Complete all → XP = 100  
Go back Day 1: Uncomplete → XP = 50   ✅ Recalculated!
Re-complete Day 1 → XP = 100           ✅ Recalculated!
```

---

## 🔧 Next Steps (For You to Implement)

### Step 3: Migrate to Derived XP

**CURRENT CODE (Incremental - BAD):**
```swift
// ❌ In checkAndAwardMissingXPForPreviousDays()
XPManager.shared.userProgress.totalXP += 50  // Incremental mutation
```

**REPLACE WITH (Derived - GOOD):**
```swift
// ✅ Calculate completed days count
let completedDays = countCompletedDays(from: habits)

// ✅ Set XP from calculation (idempotent)
XPManager.shared.publishXP(completedDaysCount: completedDays)
```

### Step 4: Helper Function

Add this to HomeTabView:
```swift
private func countCompletedDays(from habits: [Habit]) -> Int {
    guard let userId = AuthenticationManager.shared.currentUser?.uid else { return 0 }
    
    let today = DateUtils.today()
    guard let earliestStartDate = habits.map({ $0.startDate }).min() else { return 0 }
    
    var completedCount = 0
    var currentDate = DateUtils.startOfDay(for: earliestStartDate)
    
    while currentDate <= today {
        let habitsForDate = habits.filter { shouldShowHabitOnDate($0, date: currentDate) }
        let allCompleted = !habitsForDate.isEmpty && habitsForDate.allSatisfy { $0.isCompleted(for: currentDate) }
        
        if allCompleted {
            completedCount += 1
        }
        
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
    }
    
    return completedCount
}
```

### Step 5: Remove View-Driven Mutations

**DELETE THIS from HomeTabView.onAppear:**
```swift
// ❌ DELETE: View-driven XP check
await checkAndAwardMissingXPForPreviousDays()
```

**REPLACE WITH habit toggle intent:**
```swift
// ✅ Only on habit toggle
private func onHabitCompleted(_ habit: Habit) {
    // ... existing code ...
    
    // Recalculate XP after toggle
    let completedDays = countCompletedDays(from: habits)
    XPManager.shared.publishXP(completedDaysCount: completedDays)
}

private func onHabitUncompleted(_ habit: Habit) {
    // ... existing code ...
    
    // Recalculate XP after toggle
    let completedDays = countCompletedDays(from: habits)
    XPManager.shared.publishXP(completedDaysCount: completedDays)
}
```

---

## 📊 Migration Checklist

### Files to Update

#### 1. `HomeTabView.swift`
- [ ] Add `countCompletedDays()` helper
- [ ] Call `publishXP()` in `onHabitCompleted()`
- [ ] Call `publishXP()` in `onHabitUncompleted()`
- [ ] **DELETE** `checkAndAwardMissingXPForPreviousDays()` entirely
- [ ] **DELETE** `.onAppear` XP check

#### 2. Search for All XP Mutations
Run this in terminal:
```bash
cd /Users/chloe/Desktop/Habitto
grep -rn "totalXP +=" --include="*.swift"
grep -rn "totalXP -=" --include="*.swift"  
grep -rn "dailyXP +=" --include="*.swift"
grep -rn "awardDailyCompletion" --include="*.swift"
```

Replace ALL with `publishXP(completedDaysCount: ...)`.

#### 3. Remove DailyAwardService (Optional)
If you migrate fully to derived XP, you can remove:
- `DailyAwardService.swift`
- `FirestoreRepository.swift` XP methods
- `DailyAward` model (or keep for history)

#### 4. Tests to Add
```swift
func testDerivedXPIsIdempotent() {
    // Day 1: Complete all
    XPManager.shared.publishXP(completedDaysCount: 1)
    XCTAssertEqual(XPManager.shared.userProgress.totalXP, 50)
    
    // Call again (should be no-op)
    XPManager.shared.publishXP(completedDaysCount: 1)
    XCTAssertEqual(XPManager.shared.userProgress.totalXP, 50)  // Still 50!
}

func testTabSwitchingDoesNotChangeXP() {
    XPManager.shared.publishXP(completedDaysCount: 1)
    let xp = XPManager.shared.userProgress.totalXP
    
    // Simulate 10 tab switches
    for _ in 0..<10 {
        XPManager.shared.publishXP(completedDaysCount: 1)
    }
    
    XCTAssertEqual(XPManager.shared.userProgress.totalXP, xp)  // Unchanged!
}

func testHistoricalEditRecalculatesXP() {
    // Day 1 & 2 complete
    XPManager.shared.publishXP(completedDaysCount: 2)
    XCTAssertEqual(XPManager.shared.userProgress.totalXP, 100)
    
    // Uncomplete Day 1
    XPManager.shared.publishXP(completedDaysCount: 1)
    XCTAssertEqual(XPManager.shared.userProgress.totalXP, 50)  // Recalculated!
    
    // Re-complete Day 1
    XPManager.shared.publishXP(completedDaysCount: 2)
    XCTAssertEqual(XPManager.shared.userProgress.totalXP, 100)  // Back to 100!
}
```

---

## 🎯 Expected Behavior After Migration

### Before (Incremental - Buggy)
```
Open app:          xp += 50  →  50
Tab switch:        xp += 50  →  100  ❌ DUPLICATE
Tab switch:        xp += 50  →  150  ❌ DUPLICATE
```

### After (Derived - Fixed)
```
Open app:          xp = 1*50  →  50
Tab switch:        xp = 1*50  →  50  ✅ No change
Tab switch:        xp = 1*50  →  50  ✅ No change
Habit toggle:      xp = 2*50  →  100 ✅ Recalculated
```

---

## 🔍 Diagnostic Logs

### What to Watch For

#### ✅ GOOD Pattern (After migration):
```
🏪 STORE_INSTANCE XPManager created: ObjectIdentifier(0x123...)
🔍 XP_SET totalXP:50 completedDays:1 delta:+50
🔍 XP_SET totalXP:100 completedDays:2 delta:+50
🔍 XP_SET totalXP:50 completedDays:1 delta:-50  (historical edit)
```

#### ❌ BAD Pattern (Still has bugs):
```
🏪 STORE_INSTANCE XPManager created: ObjectIdentifier(0x123...)
🏪 STORE_INSTANCE XPManager created: ObjectIdentifier(0x456...)  ❌ Duplicate!

OR

🔍 XP_SET totalXP:50 completedDays:1 delta:+50
🔍 XP_SET totalXP:100 completedDays:1 delta:+50  ❌ Should still be 1 day!
```

---

## 📝 Summary

### What's Fixed NOW
- ✅ Single instance enforcement (will crash if duplicate)
- ✅ Diagnostic logging (see instance IDs)
- ✅ Pure function `recalculateXP()` available
- ✅ Idempotent `publishXP()` available

### What You Need to Do
1. ✅ Test that only ONE store instance appears
2. 🔧 Add `countCompletedDays()` helper
3. 🔧 Replace all `xp +=` with `publishXP()`
4. 🗑️ Delete `.onAppear` XP logic
5. 🧪 Add unit tests

### When Complete
- XP = 50 * completedDaysCount (pure derivation)
- No more `+=` or `-=` operations
- Tab switching won't change XP
- Historical edits recalculate correctly

---

**Status:** Foundation implemented, migration pending
**Next:** Replace incremental mutations with `publishXP()`
**Files Modified:** `Core/Managers/XPManager.swift`

