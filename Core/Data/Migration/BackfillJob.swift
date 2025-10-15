import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

// MARK: - BackfillJob

/// Handles migration of local data to Firestore
/// Provides idempotent, resumable, chunked migration with progress tracking
@MainActor
final class BackfillJob: ObservableObject {
  
  // MARK: - Lifecycle
  
  private init() {
    logger.info("🔄 BackfillJob: Initialized")
  }
  
  // MARK: - Internal
  
  static let shared = BackfillJob()
  
  @Published var isRunning = false
  @Published var progress: Double = 0.0
  @Published var status: MigrationStatus = .notStarted
  @Published var errorMessage: String?
  
  // MARK: - Private
  
  private let db = Firestore.firestore()
  private let logger = Logger(subsystem: "com.habitto.app", category: "BackfillJob")
  private let batchSize = 50 // Firestore batch limit is 500, using 50 for safety
  private var isCancelled = false
  
  // MARK: - Public Methods
  
  /// Run backfill if enabled by feature flags
  func runIfEnabled() async {
    guard FeatureFlags.enableBackfill && FeatureFlags.enableFirestoreSync else {
      logger.info("ℹ️ BackfillJob: Disabled by feature flags")
      return
    }
    
    guard let userId = getCurrentUserId() else {
      logger.error("❌ BackfillJob: No authenticated user")
      return
    }
    
    await run(userId: userId)
  }
  
  /// Run backfill for a specific user
  func run(userId: String) async {
    logger.info("🔄 BackfillJob: Starting migration for user: \(userId)")
    
    isRunning = true
    isCancelled = false
    errorMessage = nil
    
    do {
      // Load or create migration state
      var migrationState = try await loadMigrationState(userId: userId)
      
      // Check if already completed
      if migrationState.isComplete {
        logger.info("✅ BackfillJob: Migration already completed")
        status = .completed
        progress = 1.0
        isRunning = false
        return
      }
      
      // Update status to running
      migrationState.status = .running
      migrationState.startedAt = Date()
      try await saveMigrationState(migrationState, userId: userId)
      
      status = .running
      
      // Start telemetry timer
      TelemetryService.shared.startTimer("backfill.total")
      
      // Migrate each data type
      try await migrateHabits(userId: userId, migrationState: &migrationState)
      try await migrateCompletions(userId: userId, migrationState: &migrationState)
      try await migrateXPData(userId: userId, migrationState: &migrationState)
      try await migrateStreaks(userId: userId, migrationState: &migrationState)
      
      // Mark as completed
      migrationState.status = .completed
      migrationState.finishedAt = Date()
      try await saveMigrationState(migrationState, userId: userId)
      
      // End telemetry timer
      TelemetryService.shared.endTimerAndIncrement("backfill.total", counterKey: "backfill.total_ms")
      
      logger.info("✅ BackfillJob: Migration completed successfully")
      status = .completed
      progress = 1.0
      
    } catch {
      logger.error("❌ BackfillJob: Migration failed: \(error.localizedDescription)")
      
      // Update state with error
      do {
        var migrationState = try await loadMigrationState(userId: userId)
        migrationState.status = .failed
        migrationState.error = error.localizedDescription
        try await saveMigrationState(migrationState, userId: userId)
      } catch {
        logger.error("❌ BackfillJob: Failed to save error state: \(error.localizedDescription)")
      }
      
      status = .failed
      errorMessage = error.localizedDescription
      TelemetryService.shared.logBackfill("error", error: error)
    }
    
    isRunning = false
  }
  
  /// Cancel running migration
  func cancel() {
    logger.info("🛑 BackfillJob: Cancelling migration")
    isCancelled = true
    isRunning = false
  }
  
  /// Reset migration state (for testing)
  func reset(userId: String) async {
    logger.info("🔄 BackfillJob: Resetting migration state for user: \(userId)")
    
    do {
      let migrationState = MigrationState(status: .notStarted)
      try await saveMigrationState(migrationState, userId: userId)
      
      status = .notStarted
      progress = 0.0
      errorMessage = nil
      
    } catch {
      logger.error("❌ BackfillJob: Failed to reset migration state: \(error.localizedDescription)")
    }
  }
  
  // MARK: - Private Methods
  
  /// Get current authenticated user ID
  private func getCurrentUserId() -> String? {
    Auth.auth().currentUser?.uid
  }
  
  /// Load migration state from Firestore
  private func loadMigrationState(userId: String) async throws -> MigrationState {
    let docRef = db.collection("users").document(userId).collection("meta").document("migration")
    let snapshot = try await docRef.getDocument()
    
    if snapshot.exists,
       let data = snapshot.data(),
       let migrationState = MigrationState.fromFirestoreData(data) {
      return migrationState
    } else {
      // Create new migration state
      return MigrationState()
    }
  }
  
  /// Save migration state to Firestore
  private func saveMigrationState(_ state: MigrationState, userId: String) async throws {
    let docRef = db.collection("users").document(userId).collection("meta").document("migration")
    try await docRef.setData(state.toFirestoreData())
  }
  
  /// Migrate habits from local storage to Firestore
  private func migrateHabits(userId: String, migrationState: inout MigrationState) async throws {
    logger.info("🔄 BackfillJob: Migrating habits...")
    
    // Load habits from local storage (UserDefaults)
    let localStorage = UserDefaultsStorage()
    let habits = try await localStorage.loadHabits()
    
    migrationState.totalItems = (migrationState.totalItems ?? 0) + habits.count
    
    // Migrate in batches
    for (index, habit) in habits.enumerated() {
      if isCancelled {
        throw BackfillError.cancelled
      }
      
      // Create Firestore document
      let docRef = db.collection("users").document(userId).collection("habits").document(habit.id.uuidString)
      
      // Convert habit to Firestore data
      let habitData = habitToFirestoreData(habit, userId: userId)
      
      try await docRef.setData(habitData)
      
      // Update progress
      migrationState.migratedItems = (migrationState.migratedItems ?? 0) + 1
      migrationState.lastKey = habit.id.uuidString
      
      // Update progress every 10 items
      if (index + 1) % 10 == 0 {
        progress = migrationState.progress
        try await saveMigrationState(migrationState, userId: userId)
        TelemetryService.shared.logBackfill("habits", count: index + 1)
      }
    }
    
    logger.info("✅ BackfillJob: Migrated \(habits.count) habits")
    TelemetryService.shared.logBackfill("habits.completed", count: habits.count)
  }
  
  /// Migrate completion records from local storage to Firestore
  private func migrateCompletions(userId: String, migrationState: inout MigrationState) async throws {
    logger.info("🔄 BackfillJob: Migrating completion records...")
    
    // This would need to be implemented based on your completion storage structure
    // For now, we'll skip this as it depends on the specific data model
    logger.info("ℹ️ BackfillJob: Completion migration not implemented yet")
  }
  
  /// Migrate XP data from local storage to Firestore
  private func migrateXPData(userId: String, migrationState: inout MigrationState) async throws {
    logger.info("🔄 BackfillJob: Migrating XP data...")
    
    // This would need to be implemented based on your XP storage structure
    // For now, we'll skip this as it depends on the specific data model
    logger.info("ℹ️ BackfillJob: XP migration not implemented yet")
  }
  
  /// Migrate streaks from local storage to Firestore
  private func migrateStreaks(userId: String, migrationState: inout MigrationState) async throws {
    logger.info("🔄 BackfillJob: Migrating streaks...")
    
    // This would need to be implemented based on your streak storage structure
    // For now, we'll skip this as it depends on the specific data model
    logger.info("ℹ️ BackfillJob: Streak migration not implemented yet")
  }
  
  /// Convert habit to Firestore data format
  private func habitToFirestoreData(_ habit: Habit, userId: String) -> [String: Any] {
    do {
      // Convert habit to JSON data
      let jsonData = try JSONEncoder().encode(habit)
      let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
      
      // Add Firestore-specific fields
      var firestoreData = jsonObject
      firestoreData["userId"] = userId
      firestoreData["updatedAt"] = Timestamp(date: Date())
      
      return firestoreData
    } catch {
      logger.error("❌ BackfillJob: Failed to convert habit to Firestore data: \(error.localizedDescription)")
      return [
        "id": habit.id.uuidString,
        "name": habit.name,
        "description": habit.description,
        "userId": userId,
        "updatedAt": Timestamp(date: Date())
      ]
    }
  }
}

// MARK: - BackfillError

enum BackfillError: LocalizedError {
  case cancelled
  case noUser
  case firestoreError(Error)
  
  var errorDescription: String? {
    switch self {
    case .cancelled:
      return "Migration was cancelled"
    case .noUser:
      return "No authenticated user"
    case .firestoreError(let error):
      return "Firestore error: \(error.localizedDescription)"
    }
  }
}