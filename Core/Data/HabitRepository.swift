import Combine
import CoreData
import FirebaseAuth
import SwiftData
import SwiftUI

// MARK: - Notification Extensions

extension Notification.Name {
  static let habitProgressUpdated = Notification.Name("habitProgressUpdated")
}

// MARK: - HabitEntity

// These are temporary stubs until the Core Data model is restored

class HabitEntity: NSManagedObject {
  @NSManaged var id: UUID?
  @NSManaged var name: String?
  @NSManaged var reminders: NSSet?
  @NSManaged var completionHistory: NSSet?
  @NSManaged var createdAt: Date?
  @NSManaged var updatedAt: Date?
  @NSManaged var lastCompleted: Date?
  @NSManaged var isArchived: Bool
  @NSManaged var color: String?
  @NSManaged var emoji: String?
  @NSManaged var streak: Int32
  @NSManaged var frequency: String?
  @NSManaged var targetAmount: Double
  @NSManaged var unit: String?
  @NSManaged var difficultyLevel: Int16
  @NSManaged var notes: String?
  @NSManaged var isActive: Bool
  @NSManaged var reminderEnabled: Bool
  @NSManaged var weekdays: String?
  @NSManaged var scheduleDays: String?
  @NSManaged var scheduleTime: Date?
  @NSManaged var habitType: String?
  @NSManaged var timeOfDay: String?
  @NSManaged var category: String?
  @NSManaged var difficultyLogs: NSSet?
  @NSManaged var colorHex: String?
  @NSManaged var habitDescription: String?
  @NSManaged var icon: String?
  @NSManaged var schedule: String?
  @NSManaged var goal: String?
  @NSManaged var reminder: String?
  @NSManaged var startDate: Date?
  @NSManaged var endDate: Date?
  @NSManaged var isCompleted: Bool
  @NSManaged var baseline: Double
  @NSManaged var target: Double
  @NSManaged var usageRecords: NSSet?

  @nonobjc
  class func fetchRequest() -> NSFetchRequest<HabitEntity> {
    NSFetchRequest<HabitEntity>(entityName: "HabitEntity")
  }
}

// MARK: - ReminderItemEntity

class ReminderItemEntity: NSManagedObject {
  @NSManaged var id: UUID?
  @NSManaged var time: Date?
  @NSManaged var isActive: Bool
  @NSManaged var message: String?
  @NSManaged var habit: HabitEntity?
}

// MARK: - CompletionRecordEntity

class CompletionRecordEntity: NSManagedObject {
  @NSManaged var id: UUID?
  @NSManaged var timestamp: Date?
  @NSManaged var progress: Double
  @NSManaged var date: Date?
  @NSManaged var habit: HabitEntity?
  @NSManaged var notes: String?
  @NSManaged var isCompleted: Bool
  @NSManaged var dateKey: String?
  @NSManaged var timeBlock: String?
}

// MARK: - DifficultyLogEntity

class DifficultyLogEntity: NSManagedObject {
  @NSManaged var id: UUID?
  @NSManaged var timestamp: Date?
  @NSManaged var difficultyLevel: Int16
  @NSManaged var difficulty: Int16 // Legacy property
  @NSManaged var context: String?
  @NSManaged var habit: HabitEntity?
  @NSManaged var notes: String?

  @nonobjc
  class func fetchRequest() -> NSFetchRequest<DifficultyLogEntity> {
    NSFetchRequest<DifficultyLogEntity>(entityName: "DifficultyLogEntity")
  }
}

// MARK: - UsageRecordEntity

class UsageRecordEntity: NSManagedObject {
  @NSManaged var id: UUID?
  @NSManaged var timestamp: Date?
  @NSManaged var action: String?
  @NSManaged var habit: HabitEntity?
  @NSManaged var dateKey: String?
  @NSManaged var amount: Double
}

// MARK: - NoteEntity

class NoteEntity: NSManagedObject {
  @NSManaged var id: UUID?
  @NSManaged var content: String?
  @NSManaged var timestamp: Date?
  @NSManaged var habit: HabitEntity?
  @NSManaged var title: String?
  @NSManaged var tags: String?
  @NSManaged var createdAt: Date?
  @NSManaged var updatedAt: Date?
}

// MARK: - HabitSyncStatus

/// Represents the current sync status of the habit repository
enum HabitSyncStatus: Equatable {
  /// All changes are synced
  case synced
  
  /// Sync is currently in progress
  case syncing
  
  /// There are pending changes waiting to sync (with count)
  case pending(count: Int)
  
  /// Sync failed with an error
  case error(Error)
  
  /// Make Error equatable for HabitSyncStatus comparison
  static func == (lhs: HabitSyncStatus, rhs: HabitSyncStatus) -> Bool {
    switch (lhs, rhs) {
    case (.synced, .synced),
         (.syncing, .syncing):
      return true
    case (.pending(let lhsCount), .pending(let rhsCount)):
      return lhsCount == rhsCount
    case (.error(let lhsError), .error(let rhsError)):
      return lhsError.localizedDescription == rhsError.localizedDescription
    default:
      return false
    }
  }
}

// MARK: - HabitRepository

///
/// This repository acts as a @MainActor facade for UI compatibility.
/// All actual data operations are handled by the HabitStore actor.
///
/// Data Storage:
/// - Habit definitions → SwiftData (primary) → UserDefaults (fallback)
/// - Completion records → SwiftData (primary) → UserDefaults (fallback)
/// - User preferences → UserDefaults
/// - Streak calculations → Computed from local data
///
/// Authentication:
/// - User login → AuthenticationManager (Firebase Auth)
/// - User tokens → Keychain (via KeychainManager)
/// - User profile → Firebase Auth
///
@MainActor
class HabitRepository: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Initialize basic functionality first
    print("✅ HabitRepository: Initializing...")
    print("✅ HabitRepository: Starting with \(habits.count) habits")

    // Load habits using the new actor
    print("✅ HabitRepository: Using HabitStore actor for data operations...")

    // Load habits immediately and wait for completion
    Task { @MainActor in
      await loadHabits(force: true)
      print("✅ HabitRepository: Initial habit loading completed with \(habits.count) habits")
    }

    // Defer CloudKit initialization to avoid crashes
    Task { @MainActor in
      await self.initializeCloudKitSafely()
    }

    // Monitor authentication state changes
    setupUserChangeMonitoring()
    
    // Initialize sync status monitoring
    initializeSyncStatusMonitoring()

    print("✅ HabitRepository: Initialization completed")
  }

  // MARK: Internal

  static let shared = HabitRepository()

  @Published var habits: [Habit] = []
  
  /// Published loading state to prevent concurrent loads
  @Published var isLoading = false
  
  /// Cache timestamp to prevent excessive reloads
  private var lastLoadTime: Date?
  private let loadCacheInterval: TimeInterval = 1.0 // 1 second cache

  /// Published properties for UI
  @Published var shouldShowMigrationView = false
  
  // MARK: - Sync Status Properties
  
  /// Current sync status
  @Published var syncStatus: HabitSyncStatus = .synced
  
  /// Number of unsynced changes (events, completions, awards)
  @Published var unsyncedCount: Int = 0
  
  /// Timestamp of last successful sync
  @Published var lastSyncDate: Date?

  /// Debug method to check if repository is working
  func debugRepositoryState() {
    print("🔍 HabitRepository: Debug State")
    print("  - habits.count: \(habits.count)")
    print("  - habits: \(habits.map { "\($0.name) (ID: \($0.id))" })")
    print("  - habitStore: \(habitStore)")
  }

  // MARK: - Guest Data Migration

  /// Handle guest data migration completion
  func handleMigrationCompleted() {
    shouldShowMigrationView = false
    Task {
      await loadHabits(force: true)
    }
  }

  /// Handle starting fresh (no migration)
  func handleStartFresh() {
    shouldShowMigrationView = false
    Task {
      await loadHabits(force: true)
    }
  }

  /// Emergency fix for repeated migration screen - clears stale guest data
  func fixRepeatedMigrationIssue() {
    print("🚨 HabitRepository: Applying emergency fix for repeated migration screen...")

    // ✅ FIX #23: Actually migrate guest data instead of clearing it
    if guestDataMigration.hasGuestData() {
      print("⚠️ HabitRepository: Guest data detected during emergency fix - attempting migration...")
      Task {
        do {
          try await guestDataMigration.migrateGuestData()
          print("✅ HabitRepository: Guest data migrated successfully during emergency fix")
        } catch {
          print("❌ HabitRepository: Guest migration failed: \(error)")
          print("⚠️ Guest data PRESERVED - user can retry migration later")
          // ❌ CRITICAL FIX: NEVER auto-delete user data - let them choose
          // guestDataMigration.clearStaleGuestData()  // Removed to prevent data loss
        }
        
        // Hide migration view and reload
        await MainActor.run {
          shouldShowMigrationView = false
        }
        await loadHabits(force: true)
      }
    } else {
      print("ℹ️ HabitRepository: No guest data to migrate")
      // Force mark migration as completed
      guestDataMigration.forceMarkMigrationCompleted()
      
      // Hide migration view
      shouldShowMigrationView = false
      
      // Reload habits
      Task {
        await loadHabits(force: true)
      }
    }

    print("✅ HabitRepository: Emergency fix applied - migration screen should no longer appear")
  }

  // MARK: - Emergency Recovery Methods

  /// Emergency method to recover lost habits by forcing a reload
  func emergencyRecoverHabits() async {
    print("🚨 HabitRepository: Emergency habit recovery initiated...")

    // Clear any cached data
    await MainActor.run {
      self.habits = []
      self.objectWillChange.send()
    }

    // Force reload from storage
    await loadHabits(force: true)

    print("🚨 HabitRepository: Emergency recovery completed. Found \(habits.count) habits.")
  }

  // MARK: - Debug Methods

  func debugHabitsState() {
    print("🔍 HabitRepository: Debug - Current habits state:")
    print("  - Published habits count: \(habits.count)")

    // List all published habits
    print("📋 Published habits:")
    for (index, habit) in habits.enumerated() {
      print("  \(index): \(habit.name) (ID: \(habit.id), reminders: \(habit.reminders.count))")
    }

    // Check for any habits without IDs
    let invalidHabits = habits.filter { $0.id == UUID() }
    if !invalidHabits.isEmpty {
      print("⚠️ HabitRepository: Found \(invalidHabits.count) habits with default UUIDs")
    }

    // Check for duplicate IDs
    var seenIds: Set<UUID> = []
    var duplicates: [Habit] = []
    for habit in habits {
      if seenIds.contains(habit.id) {
        duplicates.append(habit)
      } else {
        seenIds.insert(habit.id)
      }
    }

    if !duplicates.isEmpty {
      print("⚠️ HabitRepository: Found \(duplicates.count) duplicate habits:")
      for duplicate in duplicates {
        print("    - \(duplicate.name) (ID: \(duplicate.id))")
      }
    }

    print("✅ HabitRepository: Debug completed")
  }

  func debugCreateHabitFlow(_ habit: Habit) {
    print("🔍 HabitRepository: Debug Create Habit Flow")
    print("  - Habit to create: \(habit.name) (ID: \(habit.id))")
    print("  - Current habits count: \(habits.count)")
    print("  - Current habits: \(habits.map { $0.name })")
  }

  /// Emergency recovery method
  func recoverMissingHabits() {
    print("🚨 HabitRepository: Starting emergency habit recovery...")

    // Force reload habits from storage
    Task {
      await loadHabits(force: true)
      print("🚨 Recovery complete: \(habits.count) habits recovered")
    }
  }

  /// Debug function to analyze user data distribution
  func debugUserStats() async {
    print("\n" + String(repeating: "=", count: 60))
    print("📊 USER STATISTICS DEBUG REPORT")
    print(String(repeating: "=", count: 60) + "\n")
    
    // 1. Current authentication state
    let currentUserId = await CurrentUser().id
    let isGuest = await CurrentUser().isGuest
    let currentEmail = await CurrentUser().email
    
    print("🔐 Current Authentication State:")
    print("  - User ID: \(currentUserId.isEmpty ? "(guest)" : currentUserId)")
    print("  - Is Guest: \(isGuest)")
    print("  - Email: \(currentEmail ?? "N/A")")
    print()
    
    // 2. Load ALL habits from SwiftData (bypassing user filter)
    do {
        let container = SwiftDataContainer.shared.modelContainer
        let context = container.mainContext
        
        // Fetch ALL HabitData without filtering
        let allDescriptor = FetchDescriptor<HabitData>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let allHabitData = try context.fetch(allDescriptor)
        
        // Separate by user type
        let guestHabits = allHabitData.filter { $0.userId.isEmpty || $0.userId == "" }
        let authenticatedHabits = allHabitData.filter { !$0.userId.isEmpty && $0.userId != "" }
        
        // Get unique user IDs
        let uniqueUserIds = Set(authenticatedHabits.map { $0.userId })
        
        print("📊 SwiftData Analysis:")
        print("  - Total habits in database: \(allHabitData.count)")
        print("  - Guest habits (userId=\"\"): \(guestHabits.count)")
        print("  - Authenticated habits: \(authenticatedHabits.count)")
        print("  - Unique authenticated users: \(uniqueUserIds.count)")
        print()
        
        // 3. Show guest habit details if any exist
        if !guestHabits.isEmpty {
            print("⚠️  GUEST HABITS DETECTED:")
            for (index, habitData) in guestHabits.prefix(10).enumerated() {
                let completionCount = habitData.completionHistory.count
                print("  [\(index + 1)] \(habitData.name)")
                print("      - Created: \(habitData.createdAt.formatted())")
                print("      - Completions: \(completionCount)")
            }
            if guestHabits.count > 10 {
                print("  ... and \(guestHabits.count - 10) more")
            }
            print()
        }
        
        // 4. Show authenticated user breakdown
        if !uniqueUserIds.isEmpty {
            print("👥 AUTHENTICATED USERS:")
            for userId in uniqueUserIds {
                let userHabits = authenticatedHabits.filter { $0.userId == userId }
                let isCurrent = userId == currentUserId
                print("  - User: \(userId.prefix(8))... \(isCurrent ? "(CURRENT)" : "")")
                print("    Habits: \(userHabits.count)")
            }
            print()
        }
        
        // 5. Check for orphaned data
        let currentUserHabits = allHabitData.filter { $0.userId == currentUserId }
        print("🎯 Current User Data:")
        print("  - Visible habits (published): \(habits.count)")
        print("  - Habits in SwiftData: \(currentUserHabits.count)")
        
        if habits.count != currentUserHabits.count {
            print("  ⚠️  MISMATCH: Published count doesn't match SwiftData!")
        }
        print()
        
        // 6. Migration risk assessment
        print("🚨 RISK ASSESSMENT:")
        if guestHabits.count > 0 && !isGuest {
            print("  ⚠️  HIGH RISK: Guest habits exist but user is authenticated!")
            print("     These habits are ORPHANED and invisible to the user.")
            print("     User may have lost \(guestHabits.count) habits when they signed in.")
        } else if guestHabits.count > 0 && isGuest {
            print("  ⚠️  MEDIUM RISK: User has \(guestHabits.count) guest habits.")
            print("     These will become orphaned if user signs in without proper migration.")
        } else if guestHabits.count == 0 && !isGuest {
            print("  ✅ LOW RISK: No guest habits, user is authenticated.")
        } else {
            print("  ✅ LOW RISK: Fresh installation or no data.")
        }
        print()
        
        // 7. Actionable recommendations
        print("💡 RECOMMENDATIONS:")
        if guestHabits.count > 0 && !isGuest {
            print("  1. User has orphaned guest data - consider migration")
            print("  2. Run data recovery to restore these habits")
        } else if guestHabits.count > 0 && isGuest {
            print("  1. Fix guest migration before user signs in")
            print("  2. Implement proper data migration flow")
        } else {
            print("  1. No immediate action needed")
        }
        
    } catch {
        print("❌ Error analyzing user data: \(error)")
        print("   \(error.localizedDescription)")
    }
    
    print("\n" + String(repeating: "=", count: 60))
    print("END OF DEBUG REPORT")
    print(String(repeating: "=", count: 60) + "\n")
  }

  // MARK: - Load Habits

  func loadHabits(force: Bool = false) async {
    // ✅ FIX: Prevent concurrent loads to reduce excessive data loading
    if isLoading {
      print("⚠️ LOAD_HABITS: Skipping load - already loading")
      return
    }
    
    // ✅ FIX: Use cache to prevent excessive reloads within short time window
    if !force, let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < loadCacheInterval {
      print("ℹ️ LOAD_HABITS: Skipping load - recently loaded \(String(format: "%.1f", Date().timeIntervalSince(lastLoad)))s ago")
      return
    }
    
    print("🔄 LOAD_HABITS_START: Loading from storage (force: \(force))")

    // Always load if force is true, or if habits is empty
    if !force, !habits.isEmpty, lastLoadTime != nil {
      print("ℹ️ LOAD_HABITS: Skipping load - habits not empty and not forced")
      return
    }

    isLoading = true
    defer { 
      isLoading = false
      lastLoadTime = Date() // ✅ Update cache timestamp
    }

    do {
      // Use the HabitStore actor for data operations
      let loadedHabits = try await habitStore.loadHabits()
      print("🔄 LOAD_HABITS_COMPLETE: Loaded \(loadedHabits.count) habits")

      // Debug each loaded habit with progress for today
      let todayKey = Habit.dateKey(for: Date())
      for (index, habit) in loadedHabits.enumerated() {
        let progress = habit.completionHistory[todayKey] ?? 0
        let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
        let isComplete = progress >= goalAmount
        print("🔄 LOAD_HABITS: [\(index)] \(habit.name) - progress=\(progress)/\(goalAmount) complete=\(isComplete)")
      }

      // Deduplicate habits by ID to prevent duplicates
      var uniqueHabits: [Habit] = []
      var seenIds: Set<UUID> = []

      for habit in loadedHabits {
        if !seenIds.contains(habit.id) {
          uniqueHabits.append(habit)
          seenIds.insert(habit.id)
        } else {
          print(
            "⚠️ HabitRepository: Found duplicate habit with ID: \(habit.id), name: \(habit.name) - skipping")
        }
      }

      // Update on main thread and notify observers
      await MainActor.run {
        self.habits = uniqueHabits
        self.objectWillChange.send()
      }

    } catch {
      print("❌ HabitRepository: Failed to load habits: \(error.localizedDescription)")
      // Keep existing habits if loading fails
    }
  }

  // MARK: - Save Difficulty Rating

  func saveDifficultyRating(habitId: UUID, date: Date, difficulty: Int32) {
    Task {
      do {
        // Use the HabitStore actor for data operations
        try await habitStore.saveDifficultyRating(
          habitId: habitId,
          date: date,
          difficulty: difficulty)

        // Update the local habits array immediately for UI responsiveness
        if let habitIndex = habits.firstIndex(where: { $0.id == habitId }) {
          habits[habitIndex].recordDifficulty(Int(difficulty), for: date)
          objectWillChange.send()
        }

        print("✅ HabitRepository: Saved difficulty \(difficulty) for habit \(habitId) on \(date)")

      } catch {
        print("❌ HabitRepository: Failed to save difficulty: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Fetch Difficulty Data

  func fetchDifficultiesForHabit(_ habitId: UUID, month: Int, year: Int) async -> [Double] {
    do {
      // Use the HabitStore actor for data operations
      return try await habitStore.fetchDifficultiesForHabit(habitId, month: month, year: year)
    } catch {
      print("❌ HabitRepository: Failed to fetch difficulties: \(error.localizedDescription)")
      return []
    }
  }

  func fetchAllDifficulties(month: Int, year: Int) async -> [Double] {
    do {
      // Use the HabitStore actor for data operations
      return try await habitStore.fetchAllDifficulties(month: month, year: year)
    } catch {
      print("❌ HabitRepository: Failed to fetch all difficulties: \(error.localizedDescription)")
      return []
    }
  }

  // MARK: - Save Habits

  func saveHabits(_ habits: [Habit]) {
    print("🔄 HabitRepository: saveHabits called with \(habits.count) habits")

    Task {
      do {
        // Use the HabitStore actor for data operations
        try await habitStore.saveHabits(habits)

        // Update the local habits array on main thread
        await MainActor.run {
          self.habits = habits
          self.objectWillChange.send()
        }

        // Trigger CloudKit sync if enabled
        if cloudKitIntegration.isEnabled {
          await cloudKitIntegration.startSync()
        }

        print("✅ HabitRepository: Successfully saved \(habits.count) habits")

      } catch {
        print("❌ HabitRepository: Failed to save habits: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Create Habit

  func createHabit(_ habit: Habit) async {
    #if DEBUG
    print("🎯 [5/8] HabitRepository.createHabit: persisting habit")
    print("  → Habit: '\(habit.name)', ID: \(habit.id)")
    print("  → Current habits count: \(habits.count)")
    #endif

    do {
      // Use the HabitStore actor for data operations
      #if DEBUG
      print("  → Calling HabitStore.createHabit")
      #endif
      try await habitStore.createHabit(habit)
      #if DEBUG
      print("  → HabitStore.createHabit completed")
      #endif

      // Reload habits to get the updated list
      #if DEBUG
      print("  → Reloading habits from storage")
      #endif
      await loadHabits(force: true)
      #if DEBUG
      print("  ✅ Success! New habits count: \(habits.count)")
      #endif

    } catch {
      #if DEBUG
      print("  ❌ FAILED: \(error.localizedDescription)")
      print("  ❌ Error type: \(type(of: error))")
      if let dataError = error as? DataError {
        print("  ❌ DataError: \(dataError)")
      }
      #endif
    }
  }

  // MARK: - Update Habit

  /// ✅ CRITICAL FIX: Made async/await to GUARANTEE save completion before returning
  func updateHabit(_ habit: Habit) async throws {
    print("🔄 HabitRepository: updateHabit called for: \(habit.name) (ID: \(habit.id))")
    print("🔄 HabitRepository: Habit has \(habit.reminders.count) reminders")
    print("🔄 HabitRepository: Current habits count before update: \(habits.count)")
    print("🎯 PERSISTENCE FIX: Using async/await to guarantee save completion")

    do {
      // Use the HabitStore actor for data operations
      print("🔄 HabitRepository: Calling habitStore.updateHabit...")
      try await habitStore.updateHabit(habit)
      print("✅ HabitRepository: habitStore.updateHabit completed successfully")

      // Reload habits to get the updated list
      print("🔄 HabitRepository: Reloading habits...")
      await loadHabits(force: true)
      print("✅ HabitRepository: Habits reloaded, new count: \(habits.count)")
      print("✅ GUARANTEED: Habit update persisted to SwiftData")

    } catch {
      print("❌ HabitRepository: Failed to update habit: \(error.localizedDescription)")
      print("❌ HabitRepository: Error type: \(type(of: error))")
      if let dataError = error as? DataError {
        print("❌ HabitRepository: DataError details: \(dataError)")
      }
      throw error
    }
  }

  // MARK: - Delete Habit

  /// ✅ CRITICAL FIX: Made async/await to GUARANTEE save completion before returning
  func deleteHabit(_ habit: Habit) async throws {
    // Remove all notifications for this habit first
    NotificationManager.shared.removeAllNotifications(for: habit)
    print("🎯 PERSISTENCE FIX: Using async/await to guarantee delete completion")

    do {
      // Use the HabitStore actor for data operations
      try await habitStore.deleteHabit(habit)
      
      // Reload habits to get the updated list
      await loadHabits(force: true)
      print("✅ GUARANTEED: Habit deleted from SwiftData")

    } catch {
      print("❌ HabitRepository: Failed to delete habit: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Clear All Habits

  func clearAllHabits() async throws {
    print("🗑️ HabitRepository: Clearing all habits")

    // Remove all notifications
    NotificationManager.shared.removeAllPendingNotifications()

    // Use the HabitStore actor for data operations
    try await habitStore.clearAllHabits()

    // Update local state
    await MainActor.run {
      self.habits = []
      self.objectWillChange.send()
    }

    print("✅ HabitRepository: All habits cleared")
  }

  // MARK: - Toggle Habit Completion

  /// ✅ CRITICAL FIX: Made async/await to GUARANTEE save completion before returning
  func toggleHabitCompletion(_ habit: Habit, for date: Date) async throws {
    // Skip Core Data and handle completion directly in UserDefaults
    print("⚠️ HabitRepository: Bypassing Core Data for toggleHabitCompletion")

    let dateKey = Habit.dateKey(for: date)  // ✅ Uses device timezone
    
    // ✅ UNIVERSAL RULE: Both types use completionHistory
    let currentProgress = habit.completionHistory[dateKey] ?? 0
    
    if habit.habitType == .breaking {
      print("🔍 TOGGLE - Breaking Habit '\(habit.name)' | Current progress: \(currentProgress)")
    } else {
      print("🔍 TOGGLE - Formation Habit '\(habit.name)' | Current progress: \(currentProgress)")
    }
    
    let newProgress = currentProgress > 0 ? 0 : 1
    print("🔍 TOGGLE - Setting new progress to: \(newProgress)")

    // ✅ CRITICAL FIX: Await save completion
    try await setProgress(for: habit, date: date, progress: newProgress)
  }

  // MARK: - Force Save All Changes

  func forceSaveAllChanges() {
    print("🔄 HabitRepository: Force saving all changes...")

    // Save current habits
    saveHabits(habits)

    print("✅ HabitRepository: All changes saved")
  }

  // MARK: - Set Progress

  /// ✅ CRITICAL FIX: Made async/await to GUARANTEE save completion before returning
  func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    let dateKey = Habit.dateKey(for: date)  // ✅ Uses device timezone
    print(
      "🔄 HabitRepository: Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
    print(
      "🎯 PERSISTENCE FIX: Using async/await to guarantee save completion")

    // Update the local habits array immediately for UI responsiveness
    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
      // ✅ UNIVERSAL RULE: Both Formation and Breaking habits write to completionHistory
      // The actualUsage field is DISPLAY ONLY and NOT used for completion logic
      let oldProgress = habits[index].completionHistory[dateKey] ?? 0
      
      // ✅ CRITICAL FIX: Create a mutable copy to modify
      var updatedHabit = habits[index]
      updatedHabit.completionHistory[dateKey] = progress
      print("🔍 REPO - \(updatedHabit.habitType == .breaking ? "Breaking" : "Formation") Habit '\(updatedHabit.name)' | Old progress: \(oldProgress) → New progress: \(progress)")

      // ✅ UNIVERSAL RULE: Both Formation and Breaking habits use IDENTICAL completion logic
      // Set completionStatus[dateKey] = true when progress >= goal
      let goalAmount = StreakDataCalculator.parseGoalAmount(from: updatedHabit.goal)
      let isComplete = progress >= goalAmount
      updatedHabit.completionStatus[dateKey] = isComplete
      print("🔍 COMPLETION FIX - \(updatedHabit.habitType == .breaking ? "Breaking" : "Formation") Habit '\(updatedHabit.name)' | Progress: \(progress) | Goal: \(goalAmount) | Completed: \(isComplete)")

      // Handle timestamp recording for time-based completion analysis
      let currentTimestamp = Date()
      if progress > oldProgress {
        // Progress increased - record new completion timestamp
        if updatedHabit.completionTimestamps[dateKey] == nil {
          updatedHabit.completionTimestamps[dateKey] = []
        }
        let newCompletions = progress - oldProgress
        for _ in 0 ..< newCompletions {
          updatedHabit.completionTimestamps[dateKey]?.append(currentTimestamp)
        }
        print(
          "🕐 HabitRepository: Recorded \(newCompletions) completion timestamp(s) for \(habit.name) at \(currentTimestamp)")
        print(
          "🕐 HabitRepository: Total timestamps for \(dateKey): \(updatedHabit.completionTimestamps[dateKey]?.count ?? 0)")
      } else if progress < oldProgress {
        // Progress decreased - remove recent timestamps
        let removedCompletions = oldProgress - progress
        for _ in 0 ..< removedCompletions {
          if updatedHabit.completionTimestamps[dateKey]?.isEmpty == false {
            updatedHabit.completionTimestamps[dateKey]?.removeLast()
          }
        }
        print(
          "🕐 HabitRepository: Removed \(removedCompletions) completion timestamp(s) for \(habit.name)")
      }

      // ✅ CRITICAL FIX: Reassign to habits array to trigger @Published emission
      habits[index] = updatedHabit
      
      // ✅ PHASE 4: Streak is now computed-only, no need to update
      // Streak is derived from completion history in real-time
      print("✅ HabitRepository: UI updated immediately for habit '\(habit.name)' on \(dateKey)")
      print("📢 HabitRepository: @Published habits array updated, triggering subscriber notifications")

      // ✅ XP SYSTEM: XP awarding is now handled by the UI layer (HomeTabView)
      // Removed automatic XP check here to prevent double celebrations

      // Send notification for UI components to update
      print(
        "🎯 HabitRepository: Posting habitProgressUpdated notification for habit: \(habit.name), progress: \(progress)")
      NotificationCenter.default.post(
        name: .habitProgressUpdated,
        object: nil,
        userInfo: ["habitId": habit.id, "progress": progress, "dateKey": dateKey])
      print("🎯 HabitRepository: Notification posted successfully")
      
      // ✅ CRITICAL FIX: Await save completion BEFORE returning
      do {
        let startTime = Date()
        print("  🎯 PERSIST_START: \(habit.name) progress=\(progress) date=\(dateKey)")
        print("  ⏱️ REPO_AWAIT_START: Calling habitStore.setProgress() at \(DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .medium))")
        
        try await habitStore.setProgress(for: habit, date: date, progress: progress)
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        print("  ⏱️ REPO_AWAIT_END: habitStore.setProgress() returned at \(DateFormatter.localizedString(from: endTime, dateStyle: .none, timeStyle: .medium))")
        print("  ✅ PERSIST_SUCCESS: \(habit.name) saved in \(String(format: "%.3f", duration))s")
        print("  ✅ GUARANTEED: Data persisted to SwiftData")
        
        // ✅ CRITICAL FIX: Reload habits from SwiftData to refresh completionStatus from CompletionRecords
        // This ensures streak calculation uses the latest data
        print("  🔄 STREAK_FIX: Reloading habits to refresh completionStatus for streak calculation...")
        await loadHabits(force: true)
        
        // ✅ DEBUG: Verify streak calculation after reload
        if let reloadedIndex = habits.firstIndex(where: { $0.id == habit.id }) {
          let reloadedHabit = habits[reloadedIndex]
          let todayKey = Habit.dateKey(for: Date())
          let todayCompleted = reloadedHabit.isCompleted(for: Date())
          let calculatedStreak = reloadedHabit.calculateTrueStreak()
          print("  🔍 STREAK_VERIFY: After reload - todayKey: \(todayKey), todayCompleted: \(todayCompleted), calculatedStreak: \(calculatedStreak)")
          print("  🔍 STREAK_VERIFY: completionStatus[\(todayKey)] = \(reloadedHabit.completionStatus[todayKey] ?? false)")
          print("  🔍 STREAK_VERIFY: completionHistory[\(todayKey)] = \(reloadedHabit.completionHistory[todayKey] ?? 0)")
        }

      } catch {
        print("  ❌ PERSIST_FAILED: \(habit.name) - \(error.localizedDescription)")
        print("  ❌ Error type: \(type(of: error))")
        print("  ❌ Error details: \(error)")
        
        // Revert UI change on error
        var revertedHabit = habits[index]
        revertedHabit.completionHistory[dateKey] = oldProgress
        habits[index] = revertedHabit
        print("  🔄 PERSIST_REVERT: Reverted \(habit.name) to progress=\(oldProgress)")
        print("  📢 HabitRepository: @Published habits array reverted, triggering subscriber notifications")
        
        // Re-throw to let caller know save failed
        throw error
      }
    }
  }

  // MARK: - Get Progress

  /// Get progress for a habit on a specific date
  /// 
  /// ⚠️ TODO: Update to use event replay (Priority 1)
  /// Get progress using event-sourcing with fallback to completionHistory
  /// ✅ FIXED: Ensures completionHistory is used correctly (populated from CompletionRecords on load)
  func getProgress(for habit: Habit, date: Date) -> Int {
    // First check completionHistory (populated from CompletionRecords when habits are loaded)
    let progress = habit.getProgress(for: date)
    
    // 🔍 DEBUG: Log if progress is 0 but completionStatus suggests completion
    let dateKey = Habit.dateKey(for: date)
    if progress == 0, let isCompleted = habit.completionStatus[dateKey], isCompleted {
      print("⚠️ getProgress MISMATCH: habit=\(habit.name), dateKey=\(dateKey), progress=0 but completionStatus=true")
      print("   → completionHistory keys: \(Array(habit.completionHistory.keys.sorted()))")
    }
    
    return progress
  }

  // MARK: - Clean Up Duplicates

  func cleanupDuplicateHabits() {
    print("🔄 HabitRepository: Starting duplicate cleanup...")

    // Check for duplicate IDs in current habits
    var seenIds: Set<UUID> = []
    var duplicatesToRemove: [Habit] = []

    for habit in habits {
      if seenIds.contains(habit.id) {
        duplicatesToRemove.append(habit)
        print(
          "⚠️ HabitRepository: Found duplicate habit with ID: \(habit.id), name: \(habit.name) - will be removed")
      } else {
        seenIds.insert(habit.id)
      }
    }

    if !duplicatesToRemove.isEmpty {
      print("🔄 HabitRepository: Removing \(duplicatesToRemove.count) duplicate habits...")

      // Remove duplicates from habits array
      habits.removeAll { habit in
        duplicatesToRemove.contains { $0.id == habit.id }
      }

      // Save updated habits
      saveHabits(habits)
      print("✅ HabitRepository: Duplicate cleanup completed, total habits: \(habits.count)")
    } else {
      print("✅ HabitRepository: No duplicate habits found")
    }
  }

  // MARK: Private

  /// Use the new HabitStore actor for all data operations
  private let habitStore = HabitStore.shared

  /// Authentication manager for user change monitoring
  private let authManager = AuthenticationManager.shared

  /// UserDefaults for storing migration attempt counts
  private let userDefaults = UserDefaults.standard

  /// Combine cancellables for subscriptions
  private var cancellables = Set<AnyCancellable>()

  /// Guest data migration
  private let guestDataMigration = GuestDataMigration()

  // Defer CloudKit initialization to avoid crashes
  private lazy var cloudKitManager = CloudKitManager.shared
  private lazy var cloudKitIntegration = CloudKitIntegrationService.shared

  // MARK: - Safe CloudKit Initialization

  private func initializeCloudKitSafely() async {
    // Initialize CloudKit integration safely
    await cloudKitIntegration.initialize()
    print("✅ HabitRepository: CloudKit integration initialized safely")

    // Initialize CloudKit sync safely
    if cloudKitManager.isCloudKitAvailable() {
      cloudKitManager.initializeCloudKitSync()
    } else {
      print("ℹ️ HabitRepository: CloudKit not available, skipping sync initialization")
    }

    // Monitor app lifecycle to reload data when app becomes active
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil)
  }

  // MARK: - User Change Monitoring

  private func setupUserChangeMonitoring() {
    // Monitor authentication state changes
    authManager.$authState
      .receive(on: DispatchQueue.main)
      .sink { [weak self] authState in
        Task { @MainActor in
          await self?.handleUserChange(authState)
        }
      }
      .store(in: &cancellables)
  }
  
  // MARK: - Sync Status Monitoring
  
  /// Initialize sync status monitoring and load initial state
  private func initializeSyncStatusMonitoring() {
    // Load last sync date from UserDefaults
    Task {
      await loadLastSyncDate()
    }
    
    // Update unsynced count periodically
    Task {
      await updateUnsyncedCount()
    }
    
    // Set up periodic updates (every 5 seconds)
    Timer.publish(every: 5.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        Task { @MainActor in
          await self?.updateUnsyncedCount()
        }
      }
      .store(in: &cancellables)
  }
  
  /// Query SwiftData for unsynced events, completions, and awards count
  func updateUnsyncedCount() async {
    let userId = await CurrentUser().idOrGuest
    
    // Skip for guest users
    guard !CurrentUser.isGuestId(userId) else {
      unsyncedCount = 0
      syncStatus = .synced
      return
    }
    
    let modelContext = SwiftDataContainer.shared.modelContext
    
    // Count unsynced events
    let eventsDescriptor = ProgressEvent.unsyncedEvents()
    let unsyncedEvents = (try? modelContext.fetch(eventsDescriptor)) ?? []
    let eventsCount = unsyncedEvents.count
    
    // Count unsynced completions (completion records without synced flag are considered synced via events)
    // For now, we'll focus on events. If needed, we can add completion sync tracking later
    
    // Count unsynced awards
    // TODO: Add synced property to DailyAward SwiftData model if needed
    // For now, awards are synced via SyncEngine.syncAwards() but don't have a synced flag
    // We'll only count events for unsynced items until DailyAward has sync tracking
    let awardsCount = 0 // Placeholder until DailyAward sync tracking is added
    
    let totalUnsynced = eventsCount + awardsCount
    
    // Update published properties
    unsyncedCount = totalUnsynced
    
    // Update sync status based on count
    if totalUnsynced > 0 {
      if syncStatus != .syncing {
        syncStatus = .pending(count: totalUnsynced)
      }
    } else if syncStatus != .syncing {
      syncStatus = .synced
    }
  }
  
  /// Update sync status when sync starts
  func syncStarted() {
    syncStatus = .syncing
  }
  
  /// Update sync status when sync completes successfully
  func syncCompleted() {
    syncStatus = .synced
    lastSyncDate = Date()
    saveLastSyncDate()
    
    // Update unsynced count after sync
    Task {
      await updateUnsyncedCount()
    }
  }
  
  /// Update sync status when sync fails
  func syncFailed(error: Error) {
    syncStatus = .error(error)
    
    // Update unsynced count to show what still needs syncing
    Task {
      await updateUnsyncedCount()
    }
  }
  
  /// Store last sync date in UserDefaults (per user)
  private func saveLastSyncDate() {
    guard let lastSyncDate = lastSyncDate else { return }
    Task {
      let userId = await CurrentUser().idOrGuest
      guard !CurrentUser.isGuestId(userId) else { return }
      
      let key = "lastSyncDate_\(userId)"
      userDefaults.set(lastSyncDate, forKey: key)
    }
  }
  
  /// Load last sync date from UserDefaults (per user)
  private func loadLastSyncDate() async {
    let userId = await CurrentUser().idOrGuest
    guard !CurrentUser.isGuestId(userId) else {
      lastSyncDate = nil
      return
    }
    
    let key = "lastSyncDate_\(userId)"
    if let date = userDefaults.object(forKey: key) as? Date {
      lastSyncDate = date
    }
  }
  
  /// Trigger manual sync
  func triggerManualSync() async throws {
    syncStarted()
    
    do {
      let userId = await CurrentUser().idOrGuest
      guard !CurrentUser.isGuestId(userId) else {
        syncCompleted()
        return
      }
      
      // Trigger SyncEngine full sync cycle
      try await SyncEngine.shared.performFullSyncCycle(userId: userId)
      syncCompleted()
    } catch {
      syncFailed(error: error)
      throw error
    }
  }

  private func handleUserChange(_ authState: AuthenticationState) async {
    switch authState {
    case .authenticated(let user):
      print(
        "🔄 HabitRepository: User authenticated: \(user.email ?? "Unknown"), checking for guest data migration...")

      // ✅ CRITICAL FIX: Only show migration UI if user is NOT anonymous
      // Anonymous users shouldn't see migration UI - they're still in guest mode
      let isAnonymous = (user as? User)?.isAnonymous ?? false
      
      if isAnonymous {
        print("ℹ️ HabitRepository: User is anonymous - skipping migration UI (still in guest mode)")
        shouldShowMigrationView = false
        await loadHabits(force: true)
        return
      }
      
      // ✅ CRITICAL FIX: Check for guest data BEFORE migrating (so migration UI can show)
      // Only check if user is authenticated with real account (not anonymous)
      let hasGuestDataToMigrate = guestDataMigration.hasGuestData() && !guestDataMigration.hasMigratedGuestData()
      
      if hasGuestDataToMigrate {
        print("🔄 HabitRepository: Guest data detected - showing migration UI...")
        shouldShowMigrationView = true  // ✅ Show migration UI, let user choose
        print("✅ Guest data found, user can choose to migrate or start fresh")
        // Don't auto-migrate - wait for user's choice in migration UI
      } else {
        print("ℹ️ HabitRepository: No guest data to migrate or already migrated")
        shouldShowMigrationView = false
        
        // ✅ CRITICAL FIX: Auto-migrate data from anonymous user to email user (silent migration)
        // This handles the case where user was anonymous and signs up (data already in SwiftData)
        let container = SwiftDataContainer.shared.modelContainer
        let context = container.mainContext
        
        var migratedCount = 0
        
        // Migrate HabitData
        let allHabitsDescriptor = FetchDescriptor<HabitData>()
        let allHabits = (try? context.fetch(allHabitsDescriptor)) ?? []
        let guestHabits = allHabits.filter { habitData in
          habitData.userId != user.uid
        }
        
        for habitData in guestHabits {
          let oldUserId = habitData.userId
          habitData.userId = user.uid
          migratedCount += 1
          print("  ✓ Auto-migrating habit '\(habitData.name)' from userId '\(oldUserId)' to '\(user.uid)'")
        }
        
        // Migrate CompletionRecords
        let allRecordsDescriptor = FetchDescriptor<CompletionRecord>()
        let allRecords = (try? context.fetch(allRecordsDescriptor)) ?? []
        let guestRecords = allRecords.filter { record in
          record.userId != user.uid
        }
        
        for record in guestRecords {
          let oldUserId = record.userId
          record.userId = user.uid
          print("  ✓ Auto-migrating CompletionRecord from userId '\(oldUserId)' to '\(user.uid)'")
        }
        
        // Migrate DailyAwards
        let allAwardsDescriptor = FetchDescriptor<DailyAward>()
        let allAwards = (try? context.fetch(allAwardsDescriptor)) ?? []
        let guestAwards = allAwards.filter { award in
          award.userId != user.uid
        }
        
        for award in guestAwards {
          let oldUserId = award.userId
          award.userId = user.uid
          print("  ✓ Auto-migrating DailyAward from userId '\(oldUserId)' to '\(user.uid)'")
        }
        
        // Migrate UserProgressData
        let allProgressDescriptor = FetchDescriptor<UserProgressData>()
        let allProgress = (try? context.fetch(allProgressDescriptor)) ?? []
        let guestProgress = allProgress.filter { progress in
          progress.userId != user.uid
        }
        
        for progress in guestProgress {
          let oldUserId = progress.userId
          progress.userId = user.uid
          print("  ✓ Auto-migrating UserProgressData from userId '\(oldUserId)' to '\(user.uid)'")
        }
        
        // Save all changes
        if migratedCount > 0 || !guestRecords.isEmpty || !guestAwards.isEmpty || !guestProgress.isEmpty {
          do {
            try context.save()
            print("✅ HabitRepository: Successfully auto-migrated \(guestHabits.count) habits, \(guestRecords.count) completion records, \(guestAwards.count) awards, \(guestProgress.count) progress records")
          } catch {
            print("❌ HabitRepository: Failed to save migrated data: \(error.localizedDescription)")
          }
        }
        
        // Mark migration as complete if no guest data exists
        if !guestDataMigration.hasGuestData() {
          guestDataMigration.forceMarkMigrationCompleted()
        }
      }

      // Load user data
      await loadHabits(force: true)
      print("✅ HabitRepository: Data loaded for user: \(user.email ?? "Unknown")")

      // Load user's XP from SwiftData
      await loadUserXPFromSwiftData(userId: user.uid)

    case .unauthenticated:
      print("🔄 HabitRepository: User signed out, loading guest data...")
      // Instead of clearing data, load guest habits
      await loadHabits(force: true)
      print("✅ HabitRepository: Guest data loaded for unauthenticated user")

    case .authenticating:
      print("🔄 HabitRepository: User authenticating, keeping current data...")

    case .error(let error):
      print("❌ HabitRepository: Authentication error: \(error)")
    }
  }

  /// Clear all user-specific data when switching users
  private func clearUserData() async {
    // Clear any cached data and reset state
    habits = []
    objectWillChange.send()

    // Clear any user-specific cache or temporary data
    // This ensures a clean slate when switching between users
    print("✅ HabitRepository: User data cleared for account switch")
  }

  // MARK: - App Lifecycle Handling

  @objc
  private func appDidBecomeActive() {
    print("🔄 HabitRepository: App became active, reloading habits...")

    // Force reload habits from storage
    Task {
      await loadHabits(force: true)
      print("✅ HabitRepository: Habits reloaded after app became active")
    }
  }

  // MARK: - XP System Integration

  /// Check if all habits are completed for a date and award XP if so
  private func checkAndAwardXPForDate(_ date: Date) async {
    let dateKey = Habit.dateKey(for: date)  // ✅ Uses device timezone

    print("🎯 XP CHECK: Checking if all habits completed for \(dateKey)")

    // Check if all habits are completed for this date
    let allCompleted = habits.allSatisfy { habit in
      let progress = habit.getProgress(for: date)
      let goalAmount = extractNumericGoalAmount(from: habit.goal)
      return progress >= goalAmount
    }

    print("🎯 XP CHECK: All habits completed: \(allCompleted)")

    if allCompleted {
      print("🎯 XP CHECK: ✅ All habits completed, awarding XP")

      // Award XP using new Firebase-based DailyAwardService
      do {
        let awardService = DailyAwardService.shared
        try await awardService.awardDailyCompletionBonus(on: date)
        print("🎯 XP CHECK: XP awarded for all habits complete")
      } catch {
        print("❌ XP CHECK: Failed to award XP: \(error)")
      }
    } else {
      print("🎯 XP CHECK: ❌ Not all habits completed, no XP awarded")

      // Note: XP revocation handled by DailyAwardService integrity checks
      // The ledger-based system doesn't need explicit revocation
      print("🎯 XP CHECK: ❌ Not all habits completed, no XP change needed")
    }
  }

  /// Extract numeric goal amount from goal string (e.g., "3 times per day" -> 3)
  private func extractNumericGoalAmount(from goal: String) -> Int {
    let components = goal.components(separatedBy: CharacterSet.decimalDigits.inverted)
    for component in components {
      if let amount = Int(component), amount > 0 {
        return amount
      }
    }
    return 1 // Default to 1 if no number found
  }

  /// Load user's XP from SwiftData DailyAward records
  private func loadUserXPFromSwiftData(userId: String) async {
    print("🎯 XP LOAD: Loading XP from SwiftData for userId: \(userId)")

    // ✅ FIX #10: Use SwiftDataContainer's ModelContext instead of creating a new container
    // Creating a new container was causing Persistent History to delete tables
    await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      XPManager.shared.loadUserXPFromSwiftData(userId: userId, modelContext: modelContext)
      print("✅ XP LOAD: User XP loaded successfully")
    }
  }
}

// MARK: - HabitEntity Extensions

extension HabitEntity {
  func toHabit() -> Habit {
    let habitType = HabitType(rawValue: habitType ?? "formation") ?? .formation
    let color = Color.fromHex(colorHex ?? "#1C274C")

    // Convert completion history
    var completionHistory: [String: Int] = [:]
    print(
      "🔍 HabitRepository: Raw completionHistory property: \(String(describing: self.completionHistory))")

    if let completionRecords = self.completionHistory as? Set<CompletionRecordEntity> {
      print(
        "🔍 HabitRepository: Converting \(completionRecords.count) completion records for habit '\(name ?? "Unknown")'")
      for record in completionRecords {
        if let dateKey = record.dateKey {
          let progress = Int(record.progress)
          completionHistory[dateKey] = progress
          print("  📅 Converting: \(dateKey) -> \(progress)")
        }
      }
    } else {
      print("🔍 HabitRepository: No completion records found for habit '\(name ?? "Unknown")'")
      print("🔍 HabitRepository: completionHistory type: \(type(of: self.completionHistory))")
      print("🔍 HabitRepository: completionHistory is NSSet: \(self.completionHistory != nil)")
    }

    // Convert actual usage
    var actualUsage: [String: Int] = [:]
    if let usageRecords = usageRecords as? Set<UsageRecordEntity> {
      for record in usageRecords {
        if let dateKey = record.dateKey {
          actualUsage[dateKey] = Int(record.amount)
        }
      }
    }

    // Convert reminders
    var reminders: [ReminderItem] = []
    if let reminderEntities = self.reminders as? Set<ReminderItemEntity> {
      for entity in reminderEntities {
        let reminder = ReminderItem(
          id: entity.id ?? UUID(),
          time: entity.time ?? Date(),
          isActive: entity.isActive)
        reminders.append(reminder)
      }
    }

    return Habit(
      id: id ?? UUID(),
      name: name ?? "",
      description: habitDescription ?? "",
      icon: icon ?? "None",
      color: CodableColor(color),
      habitType: habitType,
      schedule: schedule ?? "everyday",
      goal: goal ?? "1 time",
      reminder: reminder ?? "No reminder",
      startDate: startDate ?? Date(),
      endDate: endDate,
      createdAt: createdAt ?? Date(),
      reminders: reminders,
      baseline: Int(baseline),
      target: Int(target),
      completionHistory: completionHistory,
      actualUsage: actualUsage)
  }
}

// MARK: - ReminderItemEntity Extensions

extension ReminderItemEntity {
  func toReminderItem() -> ReminderItem {
    ReminderItem(
      id: id ?? UUID(),
      time: time ?? Date(),
      isActive: isActive)
  }
}

// MARK: - CompletionRecordEntity Extensions

extension CompletionRecordEntity {
  func toCompletionRecord() -> (dateKey: String, progress: Int) {
    (
      dateKey: dateKey ?? "",
      progress: Int(progress))
  }
}

// MARK: - UsageRecordEntity Extensions

extension UsageRecordEntity {
  func toUsageRecord() -> (dateKey: String, amount: Int) {
    (
      dateKey: dateKey ?? "",
      amount: Int(amount))
  }
}

// MARK: - NoteEntity Extensions

extension NoteEntity {
  func toNote() -> Note {
    Note(
      id: id ?? UUID(),
      title: title ?? "",
      content: content ?? "",
      tags: (tags?.components(separatedBy: ",")
        .compactMap { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }) ?? [],
      createdAt: createdAt ?? Date(),
      updatedAt: updatedAt ?? Date())
  }
}

// MARK: - DifficultyLogEntity Extensions

extension DifficultyLogEntity {
  func toDifficultyLog() -> DifficultyLog {
    DifficultyLog(
      id: UUID(), // Generate new ID since it's not stored
      difficulty: Int(difficulty),
      context: context ?? "",
      timestamp: timestamp ?? Date())
  }
}

// MARK: - Note

struct Note {
  let id: UUID
  let title: String
  let content: String
  let tags: [String]
  let createdAt: Date
  let updatedAt: Date
}

// MARK: - DifficultyLog

struct DifficultyLog {
  let id: UUID
  let difficulty: Int // 1-10 scale
  let context: String
  let timestamp: Date
}

// MARK: - MoodLog

struct MoodLog {
  let id: UUID
  let mood: Int // 1-10 scale
  let timestamp: Date
}
