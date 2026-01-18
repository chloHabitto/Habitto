# Habitto Audit - Quick Reference Guide

**Generated**: January 18, 2026

---

## 🚨 Critical Issues (Fix Immediately)

| Issue | Location | Impact | Fix Time |
|-------|----------|---------|----------|
| **try! crash risk** | `EnhancedMigrationTelemetryManager.swift` | App crash | 15 min |
| **2,421 print() statements** | Core/ (113 files) | Performance, Production logs | 2-3 days |
| **995 force unwraps** | 187 files | Potential crashes | 1-2 weeks |
| **28 Archive files** | Core/*/Archive/ | Code confusion | 1 hour |
| **5,767 line file** | `ProgressTabView.swift` | Maintainability | 1 day |

---

## 🔍 Code Duplication Summary

### Streak Calculation (5+ implementations)
```
✅ KEEP: Core/Streaks/StreakCalculator.swift
❌ REMOVE: Core/Data/StreakDataCalculator.swift (legacy)
❌ REMOVE: Habit.calculateTrueStreak() (duplicate)
❌ REMOVE: View-level calculations (call StreakCalculator)
❌ REMOVE: Archive/StreakService.swift (old service pattern)
```

### userId Filtering (8 locations)
```
CREATE: Core/Utils/UserFiltering.swift
  - filterHabits(_:for:)
  - filterRecords(_:for:)

REPLACE IN:
  - HabitRepository.swift (5 instances)
  - HabittoApp.swift (22 instances!)
  - DailyAwardService.swift (3 instances)
  - + 5 more files
```

### DateFormatter (293 instances)
```
✅ USE: ISO8601DateHelper.shared (cached)
✅ USE: AppDateFormatter.shared (cached)
❌ REMOVE: All ad-hoc DateFormatter() creations

TOP OFFENDERS:
  - ProgressTabView.swift (30)
  - CalendarGridViews.swift (29)
  - DatePreferences.swift (16)
```

---

## 🗑️ Code to Delete

### Archive Folders (28 files, ~3,000 LOC)
```bash
rm -rf Core/Data/CloudKit/Archive/          # 8 files - CloudKit disabled
rm -rf Core/Services/Archive/               # 5 files - Old services
rm -rf Core/Migration/Archive/              # 6 files - Old migrations
rm -rf Core/Models/Archive/                 # 8 files - Old models
rm -rf Core/Utils/Archive/                  # 2 files - Old utils
```

### CloudKit Imports (10 files)
```
- Core/Managers/ICloudStatusManager.swift (still active - review)
- Core/Data/CloudKitManager.swift (still active - review)
- Core/Data/GDPRDataDeletionManager.swift (has mock)
+ 7 Archive files (covered above)
```

---

## ⚡ Performance Quick Wins

### 1. Cache DateFormatters
```swift
// BEFORE (293 instances):
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"
return formatter.string(from: date)

// AFTER:
return ISO8601DateHelper.shared.formatDate(date)
```

### 2. Batch modelContext.save()
```swift
// BEFORE (91 instances):
for habit in habits {
    habit.name = newName
    try modelContext.save() // Save per habit!
}

// AFTER:
for habit in habits {
    habit.name = newName
}
try modelContext.save() // Save once
```

### 3. Fix N+1 Queries
```swift
// BEFORE:
for habit in habits {
    let records = try await loadCompletions(for: habit.id) // N queries!
}

// AFTER:
let allRecords = try await loadCompletions(for: habitIds) // 1 query
let recordsByHabit = Dictionary(grouping: allRecords) { $0.habitId }
```

---

## 🔒 Security Checklist

### userId Validation
```swift
// STANDARDIZE THIS:
extension String {
    var isGuestUserId: Bool {
        self.isEmpty || self == "guest"
    }
}

// USE EVERYWHERE:
if userId.isGuestUserId {
    return guestData
}

// FOUND IN 30 LOCATIONS - needs standardization
```

### Force Unwrap Audit
```bash
# Priority files (user-facing):
grep -n "!" Views/Screens/*.swift
grep -n "!" Core/Models/Habit.swift
grep -n "!" Core/Data/HabitRepository.swift
```

---

## 📊 Logging Migration

### Replace print() with Logger
```swift
// ADD TO EACH FILE:
import OSLog

private let logger = Logger(subsystem: "com.habitto", category: "habits")

// REPLACE:
print("Loading habits...")                    // ❌ BAD
debugLog("Loading habits...")                 // ❌ BAD
print("🔥 STREAK: Loading...")                // ❌ BAD

// WITH:
logger.debug("Loading habits")                // ✅ GOOD
logger.info("Loaded \(count) habits")         // ✅ GOOD
logger.error("Failed to load: \(error)")      // ✅ GOOD
```

### Top Files to Fix First
```
1. SwiftDataStorage.swift           - 108 prints
2. SubscriptionManager.swift        - 332 prints
3. NotificationManager.swift        - 188 prints
4. AuthenticationManager.swift      - 81 prints
5. XPManager.swift                  - 53 prints
```

---

## 🏗️ Architecture Decisions

### Layer Simplification Options

**Current: 3 Layers**
```
UI → HabitRepository → HabitStore → SwiftDataStorage → SwiftData
     (@MainActor)       (actor)      (@MainActor)
```

**Option A: 2 Layers (Recommended)**
```
UI → HabitRepository → SwiftData
     (@MainActor)
     
Benefits:
- Simpler mental model
- Less duplication
- Easier testing
```

**Option B: Keep 3, Clarify Roles**
```
UI → HabitRepository (coordination, UI state)
     ↓
     HabitStore (business logic, validation)
     ↓
     SwiftDataStorage (persistence only)

Benefits:
- Clear separation of concerns
- Thread safety via actor
- Testable business logic
```

---

## 🧪 Testing Priorities

### Missing Test Coverage
```
HIGH PRIORITY:
- [ ] StreakCalculator.computeCurrentStreak()
- [ ] StreakCalculator.computeLongestStreakFromHistory()
- [ ] Habit.isCompleted(for:)
- [ ] userId filtering logic
- [ ] Data migration safety

MEDIUM PRIORITY:
- [ ] XP calculations
- [ ] Date utilities
- [ ] Schedule parsing
- [ ] Sync conflict resolution

LOW PRIORITY:
- [ ] UI integration tests
- [ ] Widget updates
- [ ] Analytics events
```

---

## 📝 Documentation Needed

### Architecture
```
- [ ] ARCHITECTURE.md (layer diagram)
- [ ] DATA_FLOW.md (how data moves)
- [ ] TESTING.md (how to test locally)
- [ ] LOGGING_STANDARDS.md (how to log)
```

### API Documentation
```
- [ ] StreakCalculator (/// doc comments)
- [ ] HabitRepository (/// doc comments)
- [ ] SwiftDataStorage (/// doc comments)
- [ ] All public Manager classes
```

---

## 🎯 One-Week Sprint Plan

### Day 1: Critical Safety
- [ ] Fix try! in EnhancedMigrationTelemetryManager
- [ ] Audit force unwraps in Habit.swift
- [ ] Audit force unwraps in HabitRepository.swift
- [ ] Create userId validation standard

### Day 2: Code Cleanup
- [ ] Delete Archive/ folders (28 files)
- [ ] Delete CloudKit imports
- [ ] Remove deprecated comments
- [ ] Git commit: "Remove archived code"

### Day 3: Logging Part 1
- [ ] Replace print() in SwiftDataStorage.swift (108)
- [ ] Replace print() in SubscriptionManager.swift (332)
- [ ] Replace print() in NotificationManager.swift (188)
- [ ] Create Logger+Extensions.swift

### Day 4: Logging Part 2
- [ ] Replace print() in remaining Core/Services
- [ ] Replace print() in Core/Managers
- [ ] Create LOGGING_STANDARDS.md
- [ ] Git commit: "Standardize logging"

### Day 5: Performance
- [ ] Cache DateFormatters (create utility)
- [ ] Replace ad-hoc formatters in top 5 files
- [ ] Batch modelContext.save() in loops
- [ ] Profile with Instruments

---

## 🔧 Useful Commands

### Find Duplication
```bash
# Find all streak calculation functions
grep -r "func.*[Ss]treak" --include="*.swift" Core/

# Find all userId filtering
grep -r "filter.*userId" --include="*.swift" Core/

# Find all DateFormatter creations
grep -r "DateFormatter()" --include="*.swift" Core/
```

### Find Safety Issues
```bash
# Find all force unwraps
grep -r "!" --include="*.swift" Core/ | wc -l

# Find all try?
grep -r "try?" --include="*.swift" Core/ | wc -l

# Find all try!
grep -r "try!" --include="*.swift" .
```

### Find Performance Issues
```bash
# Find all print statements
grep -r "print(" --include="*.swift" Core/ | wc -l

# Find all .shared singletons
grep -r "static let shared" --include="*.swift" Core/

# Find all @Published
grep -r "@Published" --include="*.swift" Core/
```

---

## 📊 Metrics Tracking

### Before Cleanup
```
Print statements:     2,421
Force unwraps (!):    995
Try? (silent):        266
Archive files:        28
Lines of code:        ~150,000
```

### Target After Cleanup
```
Print statements:     0
Force unwraps (!):    <100 (audited)
Try? (silent):        <50 (logged)
Archive files:        0
Lines of code:        ~140,000 (-10,000)
```

---

## 💡 Quick Reference: Common Patterns

### Good Pattern: Async Data Loading
```swift
@MainActor
func loadData() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
        let data = try await dataStore.load()
        self.items = data
        logger.info("Loaded \(data.count) items")
    } catch {
        logger.error("Failed to load: \(error)")
        CrashlyticsService.shared.record(error)
    }
}
```

### Good Pattern: Safe Unwrapping
```swift
// BAD:
let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!

// GOOD:
guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
    logger.error("Failed to calculate tomorrow")
    return date // or throw error
}
```

### Good Pattern: Batched Updates
```swift
// BAD:
for habit in habits {
    self.currentHabit = habit // Publishes N times!
}

// GOOD:
let updatedHabits = habits.map { transform($0) }
self.habits = updatedHabits // Publishes once
```

---

## 🎓 Learning Resources

### SwiftData Best Practices
- Use FetchDescriptor with predicates
- Batch saves when possible
- Use @MainActor for ModelContext
- Handle migration carefully

### Swift Concurrency
- Prefer actor isolation over locks
- Use Task.detached for heavy work
- Avoid MainActor.assumeIsolated
- Test race conditions

### Performance
- Profile with Instruments
- Cache expensive computations
- Avoid work in ViewBuilder
- Use LazyVStack for long lists

---

*End of Quick Reference*
