# Habitto Audit - Action Checklist

**Generated**: January 18, 2026  
**Status**: 🔴 Not Started

Use this checklist to track progress through the audit recommendations.

---

## 🚨 CRITICAL (Do First)

### Fix Crash Risks
- [ ] **Review try! in EnhancedMigrationTelemetryManager.swift**
  - File: `Core/Managers/EnhancedMigrationTelemetryManager.swift`
  - Action: Replace with proper error handling
  - Impact: Prevents app crash
  - Time: 15 minutes

- [ ] **Audit top 10 files with force unwraps**
  - [ ] `Core/Data/CalendarGridViews.swift` (12 unwraps)
  - [ ] `Core/Models/Habit.swift` (4 unwraps)
  - [ ] `Core/Data/SwiftData/HabitDataModel.swift` (19 unwraps)
  - [ ] `Core/Data/HabitRepository.swift` (32 unwraps)
  - [ ] `Core/Data/Repository/HabitStore.swift` (33 unwraps)
  - [ ] `Core/Data/Sync/SyncEngine.swift` (32 unwraps)
  - [ ] `Views/Screens/HomeView.swift` (12 unwraps)
  - [ ] `Views/Tabs/HomeTabView.swift` (8 unwraps)
  - [ ] `Core/UI/Components/FormInputComponents.swift` (5 unwraps)
  - [ ] `Core/UI/Items/ScheduledHabitItem.swift` (14 unwraps)
  - Action: Replace with guard/if let or ?? default
  - Impact: Prevents crashes
  - Time: 4-6 hours

### Delete Dead Code
- [ ] **Delete Archive/CloudKit/ folder**
  - Path: `Core/Data/CloudKit/Archive/`
  - Files: 8 files (ConflictResolutionPolicy.swift, CloudKitTypes.swift, etc.)
  - Impact: -500 LOC, reduced confusion
  - Time: 10 minutes

- [ ] **Delete Archive/Services/ folder**
  - Path: `Core/Services/Archive/`
  - Files: 5 files (StreakService.swift, ServiceContainer.swift, etc.)
  - Impact: -800 LOC
  - Time: 10 minutes

- [ ] **Delete Archive/Migration/ folder**
  - Path: `Core/Migration/Archive/`
  - Files: 6 files (MigrationValidator.swift, XPMigrator.swift, etc.)
  - Impact: -600 LOC
  - Time: 10 minutes

- [ ] **Delete Archive/Models/New/ folder**
  - Path: `Core/Models/Archive/New/`
  - Files: 8 files (GlobalStreakModel.swift, HabitSchedule.swift, etc.)
  - Action: First verify none are still referenced
  - Impact: -1,000 LOC
  - Time: 30 minutes

- [ ] **Delete Archive/Utils/ folder**
  - Path: `Core/Utils/Archive/`
  - Files: 2 files (DateKey.swift, EventSourcedUtils.swift)
  - Impact: -100 LOC
  - Time: 5 minutes

- [ ] **Git commit: "Remove archived code"**
  - Commit message: "Remove 28 archived files (~3,000 LOC)"

### Review CloudKit Dependencies
- [ ] **Audit ICloudStatusManager.swift**
  - File: `Core/Managers/ICloudStatusManager.swift`
  - Question: Is this still needed with CloudKit disabled?
  - Action: Remove if unused, or document why it's kept
  - Time: 30 minutes

- [ ] **Audit CloudKitManager.swift**
  - File: `Core/Data/CloudKitManager.swift`
  - Question: Is this still needed with CloudKit disabled?
  - Action: Remove if unused, or document why it's kept
  - Time: 30 minutes

- [ ] **Remove CloudKit import from GDPRDataDeletionManager**
  - File: `Core/Data/GDPRDataDeletionManager.swift`
  - Action: Remove CloudKit mock if not needed
  - Time: 15 minutes

---

## 🔴 HIGH PRIORITY (Week 1-2)

### Standardize Logging
- [ ] **Create Logger+Extensions.swift**
  ```swift
  // Core/Utils/Logger+Extensions.swift
  import OSLog
  
  extension Logger {
      static let habits = Logger(subsystem: "com.habitto", category: "habits")
      static let sync = Logger(subsystem: "com.habitto", category: "sync")
      static let auth = Logger(subsystem: "com.habitto", category: "auth")
      static let storage = Logger(subsystem: "com.habitto", category: "storage")
      static let xp = Logger(subsystem: "com.habitto", category: "xp")
      static let streak = Logger(subsystem: "com.habitto", category: "streak")
  }
  ```
  - Time: 30 minutes

- [ ] **Replace print() in top 10 files**
  - [ ] `Core/Data/SwiftData/SwiftDataStorage.swift` (108 prints)
  - [ ] `Core/Managers/SubscriptionManager.swift` (332 prints)
  - [ ] `Core/Managers/NotificationManager.swift` (188 prints)
  - [ ] `Core/Managers/AuthenticationManager.swift` (81 prints)
  - [ ] `Core/Managers/XPManager.swift` (53 prints)
  - [ ] `Core/Services/FirestoreService.swift` (42 prints)
  - [ ] `Core/Models/Habit.swift` (38 prints)
  - [ ] `Core/Services/FirebaseBackupService.swift` (47 prints)
  - [ ] `Core/Services/AccountDeletionService.swift` (33 prints)
  - [ ] `Core/Data/Repository/HabitStore.swift` (29 prints)
  - Time: 2-3 days
  - Note: Do one file at a time, test after each

- [ ] **Create LOGGING_STANDARDS.md**
  - Document: When to use .debug vs .info vs .error
  - Document: How to avoid PII in logs
  - Document: How to use #if DEBUG
  - Time: 1 hour

- [ ] **Git commit: "Standardize logging (part 1)"**

### Consolidate Streak Calculation
- [ ] **Make StreakCalculator the single source of truth**
  - File: `Core/Streaks/StreakCalculator.swift`
  - Action: Keep this as authoritative implementation
  - Time: Review only (30 minutes)

- [ ] **Deprecate StreakDataCalculator**
  - File: `Core/Data/StreakDataCalculator.swift`
  - Action: Move unique functionality to StreakCalculator
  - Action: Mark with @available(*, deprecated)
  - Time: 2 hours

- [ ] **Remove Habit.calculateTrueStreak()**
  - File: `Core/Models/Habit.swift`
  - Action: Replace calls with StreakCalculator.computeCurrentStreak()
  - Time: 1 hour

- [ ] **Remove Habit.validateStreak() and correctStreak()**
  - File: `Core/Models/Habit.swift`
  - Action: Move validation logic to StreakCalculator if needed
  - Time: 1 hour

- [ ] **Update view-level streak calculations**
  - [ ] `Views/Tabs/ProgressTabView.swift` updateStreakStatistics()
  - [ ] `Views/Screens/HomeView.swift` updateStreak()
  - [ ] `Core/Data/CalendarGridViews.swift` calculateHabitBestStreak()
  - Action: Call StreakCalculator instead of duplicating logic
  - Time: 2 hours

- [ ] **Git commit: "Consolidate streak calculation logic"**

### Standardize userId Validation
- [ ] **Create UserFiltering utility**
  ```swift
  // Core/Utils/UserFiltering.swift
  import Foundation
  
  extension String {
      var isGuestUserId: Bool {
          self.isEmpty || self == "guest"
      }
  }
  
  enum UserFiltering {
      static func filterHabits(_ habits: [Habit], for userId: String) -> [Habit] {
          habits.filter { $0.userId == userId }
      }
      
      static func filterRecords<T>(_ records: [T], for userId: String) -> [T] 
          where T: HasUserId {
          records.filter { $0.userId == userId }
      }
  }
  ```
  - Time: 30 minutes

- [ ] **Replace userId checks in 8 files**
  - [ ] `Core/Data/SwiftData/SwiftDataStorage.swift`
  - [ ] `Core/Data/HabitRepository.swift` (5 instances)
  - [ ] `Core/Data/Repository/HabitStore.swift`
  - [ ] `Core/Services/DailyAwardService.swift` (3 instances)
  - [ ] `Core/Managers/XPManager.swift` (2 instances)
  - [ ] `App/HabittoApp.swift` (22 instances!)
  - [ ] `Core/Services/DataRepairService.swift` (5 instances)
  - [ ] `Core/Data/Migration/GuestDataMigrationHelper.swift` (3 instances)
  - Time: 3 hours

- [ ] **Git commit: "Standardize userId validation"**

### Cache DateFormatters
- [ ] **Audit DateFormatter usage**
  - Count: 293 instances across 88 files
  - Goal: Reduce to ~10 cached instances
  - Time: 1 hour (audit only)

- [ ] **Enhance ISO8601DateHelper**
  - File: `Core/Utils/Date/ISO8601DateHelper.swift`
  - Action: Add cached formatters for all common patterns
  - Patterns needed: "yyyy-MM-dd", "MMM d, yyyy", "EEEE", etc.
  - Time: 2 hours

- [ ] **Replace DateFormatter in top 5 files**
  - [ ] `Views/Tabs/ProgressTabView.swift` (30 instances)
  - [ ] `Core/Data/CalendarGridViews.swift` (29 instances)
  - [ ] `Core/Utils/Design/DatePreferences.swift` (16 instances)
  - [ ] `Core/UI/Components/ExpandableCalendar.swift` (17 instances)
  - [ ] `Core/UI/Selection/CustomWeekSelectionCalendar.swift` (10 instances)
  - Time: 4 hours

- [ ] **Git commit: "Cache DateFormatters for performance"**

---

## 🟠 MEDIUM PRIORITY (Week 3-4)

### Break Up Large Files
- [ ] **Split ProgressTabView.swift**
  - Current: 5,767 lines
  - Target: Multiple files <500 lines each
  - Suggested splits:
    - ProgressTabView.swift (main view)
    - ProgressTabCalendarSection.swift
    - ProgressTabStatsSection.swift
    - ProgressTabChartSection.swift
    - ProgressTabViewModel.swift
  - Time: 1-2 days

- [ ] **Split HabitRepository.swift**
  - Current: 1,843 lines
  - Consider: Separate sync logic, migration logic
  - Time: 1 day

- [ ] **Split HabitStore.swift**
  - Current: 1,529 lines
  - Consider: Separate CRUD, validation, migration
  - Time: 1 day

### Batch modelContext.save() Operations
- [ ] **Audit save operations in SwiftDataStorage**
  - File: `Core/Data/SwiftData/SwiftDataStorage.swift` (14 saves)
  - Action: Batch related saves
  - Time: 2 hours

- [ ] **Audit save operations in SyncEngine**
  - File: `Core/Data/Sync/SyncEngine.swift` (11 saves)
  - Action: Batch related saves
  - Time: 2 hours

- [ ] **Audit save operations in Services/Archive**
  - (Will be deleted, skip if archives are removed)

### Improve Architecture Documentation
- [ ] **Create ARCHITECTURE.md**
  - Document: Current layer structure
  - Document: Data flow diagrams
  - Document: When to use each layer
  - Time: 3 hours

- [ ] **Create DATA_FLOW.md**
  - Document: How data moves from UI to storage
  - Document: Sync flow diagrams
  - Document: Migration flow
  - Time: 2 hours

- [ ] **Add API documentation**
  - [ ] StreakCalculator (/// comments)
  - [ ] HabitRepository (/// comments)
  - [ ] SwiftDataStorage (/// comments)
  - [ ] All public Manager APIs
  - Time: 4 hours

---

## 🟡 LOW PRIORITY (Week 5+)

### Consider Architecture Simplification
- [ ] **Decision: Keep 3 layers or simplify to 2?**
  - Current: UI → Repository → Store → Storage
  - Option A: UI → Repository → Storage
  - Option B: Keep 3, clarify roles
  - Time: 2 hours (discussion + decision)

- [ ] **If simplifying: Merge Store into Repository**
  - Action: Move Store logic to Repository
  - Action: Update all callsites
  - Time: 2-3 days
  - Risk: High - affects entire codebase

- [ ] **If keeping 3: Document clear responsibilities**
  - Repository: UI state, coordination
  - Store: Business logic, validation
  - Storage: Pure persistence
  - Time: 1 hour

### Review Manager Classes
- [ ] **Audit Manager necessity**
  - Total: 39 Manager classes
  - Question for each: Single responsibility? Could be merged?
  - Time: 4 hours

- [ ] **Merge EnhancedMigrationTelemetryManager into MigrationTelemetryManager**
  - Current: 2 separate managers
  - Action: Combine functionality
  - Time: 2 hours

- [ ] **Consider: ThemeManager → UserDefaults extension**
  - Current: Full Manager class
  - Consideration: Is this overkill for simple preferences?
  - Time: 1 hour

- [ ] **Consider: TutorialManager → AppState @Published**
  - Current: Full Manager class
  - Consideration: Could be simple state in AppState
  - Time: 1 hour

### Add Unit Tests
- [ ] **StreakCalculator tests**
  - [ ] Test computeCurrentStreak() with various scenarios
  - [ ] Test computeLongestStreakFromHistory()
  - [ ] Test edge cases (DST, leap year, etc.)
  - Time: 1 day

- [ ] **userId filtering tests**
  - [ ] Test guest vs authenticated filtering
  - [ ] Test empty userId handling
  - [ ] Test data isolation
  - Time: 3 hours

- [ ] **Date utilities tests**
  - [ ] Test DateFormatter caching
  - [ ] Test date calculations
  - [ ] Test timezone handling
  - Time: 1 day

- [ ] **Migration tests**
  - [ ] Test data format migrations
  - [ ] Test schema migrations
  - [ ] Test rollback scenarios
  - Time: 2 days

### Clean Up Remaining Issues
- [ ] **Remove single-conformance protocols**
  - Review 20 protocols
  - Remove if only 1 implementer
  - Time: 2 hours

- [ ] **Standardize log prefixes**
  - Replace emojis and mixed formats
  - Use OSLog categories instead
  - Time: 2 hours

- [ ] **Review all .shared singletons**
  - Total: 101 singletons
  - Question: Is each needed?
  - Consider: Dependency injection alternatives
  - Time: 4 hours

---

## 📊 Progress Tracking

### Metrics to Track

| Metric | Baseline | Current | Target |
|--------|----------|---------|--------|
| print() statements | 2,421 | ___ | 0 |
| Force unwraps (!) | 995 | ___ | <100 |
| try? (silent) | 266 | ___ | <50 |
| try! (crash) | 1 | ___ | 0 |
| Archive files | 28 | ___ | 0 |
| DateFormatter creates | 293 | ___ | ~10 |
| Lines of code | ~150K | ___ | ~140K |
| Largest file (lines) | 5,767 | ___ | <1,000 |

### Completion Status
- [ ] Critical (4 items) - 0% complete
- [ ] High Priority (6 items) - 0% complete
- [ ] Medium Priority (5 items) - 0% complete
- [ ] Low Priority (7 items) - 0% complete

**Overall Progress: 0% (0 / 22 major items)**

---

## 🎯 Sprint Planning

### Sprint 1 (Week 1): Safety & Critical Issues
**Goal**: Fix crash risks, delete dead code

Tasks:
- Fix try! crash risk
- Audit top 10 force unwrap files
- Delete all Archive folders
- Review CloudKit dependencies

**Definition of Done:**
- No try! in codebase
- Top user-facing files have safe unwrapping
- Archive folders deleted and committed
- CloudKit imports documented or removed

### Sprint 2 (Week 2): Logging Standardization
**Goal**: Replace all print() statements

Tasks:
- Create Logger+Extensions
- Replace print() in top 10 files
- Create LOGGING_STANDARDS.md
- Test logging in production build

**Definition of Done:**
- Top 10 files use Logger
- Standards documented
- No more print() in Core/

### Sprint 3 (Week 3): Consolidation
**Goal**: Single source of truth for common operations

Tasks:
- Consolidate streak calculation
- Standardize userId validation
- Cache DateFormatters
- Performance test changes

**Definition of Done:**
- StreakCalculator is only streak source
- UserFiltering utility used everywhere
- DateFormatter instances cached
- Performance regression tests pass

### Sprint 4 (Week 4): Architecture & Docs
**Goal**: Improve code structure and documentation

Tasks:
- Break up ProgressTabView
- Batch save operations
- Create ARCHITECTURE.md
- Add API documentation

**Definition of Done:**
- No files >1,000 lines
- Architecture documented
- Public APIs documented
- Code review complete

---

## 📝 Notes & Decisions

### Decision Log
| Date | Decision | Rationale | Impact |
|------|----------|-----------|--------|
| | | | |

### Blockers
| Issue | Blocker | Resolution | Status |
|-------|---------|------------|--------|
| | | | |

### Questions
| Question | Answer | Date |
|----------|--------|------|
| | | |

---

*Last Updated: 2026-01-18*
*Status: 🔴 Not Started*
