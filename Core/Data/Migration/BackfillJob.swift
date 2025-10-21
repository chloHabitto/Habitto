//
//  BackfillJob.swift
//  Habitto
//
//  Backfill job for migrating existing data to Firestore
//

import Foundation
import FirebaseFirestore
import OSLog

// MARK: - BackfillJob

/// Handles backfilling existing local data to Firestore
@MainActor
final class BackfillJob: ObservableObject {
  // MARK: Lifecycle
  
  private init() {
    // ✅ FIX: Don't access Firestore in init - use computed property instead
  }
  
  // MARK: Internal
  
  static let shared = BackfillJob()
  
  @Published var isRunning = false
  @Published var progress = 0.0
  @Published var status = "Ready"
  @Published var error: String?
  
  // MARK: Private
  
  // ✅ FIX: Use computed property to avoid accessing Firestore during class initialization
  // This ensures Firestore is only accessed AFTER it's configured in AppFirebase.swift
  private var db: Firestore { Firestore.firestore() }
  private let batchSize = 450 // Firestore batch limit
  private let maxRetries = 3
  
  // MARK: - Public Methods
  
  /// Run backfill if enabled by feature flags (non-blocking)
  func runIfEnabled() async {
    guard FeatureFlags.enableBackfill else {
      backfillLogger.info("📊 BackfillJob: Backfill disabled by feature flag")
      return
    }
    
    backfillLogger.info("🚀 BackfillJob: Starting backfill process...")
    await run()
  }
  
  /// Run the backfill process
  func run() async {
    guard !isRunning else {
      backfillLogger.warning("⚠️ BackfillJob: Already running, skipping duplicate run")
      return
    }
    
    isRunning = true
    progress = 0.0
    status = "Starting backfill..."
    error = nil
    
    backfillLogger.info("🔄 BackfillJob: Initializing migration...")
    
    do {
      // Get current user ID
      guard let userId = FirebaseConfiguration.currentUserId else {
        backfillLogger.error("❌ BackfillJob: No authenticated user found")
        throw BackfillError.notAuthenticated
      }
      
      backfillLogger.info("👤 BackfillJob: Running for user: \(userId)")
      
      // Check if migration is already complete
      let migrationState = try await getMigrationState(userId: userId)
      backfillLogger.info("📋 BackfillJob: Current migration state: \(migrationState.status.rawValue)")
      
      if migrationState.status == .complete {
        backfillLogger.info("✅ BackfillJob: Migration already complete, skipping")
        status = "Migration already complete"
        progress = 1.0
        isRunning = false
        return
      }
      
      // If migration failed previously, resume from last key
      let resumeFromKey = migrationState.status == .failed ? migrationState.lastKey : nil
      if let resumeKey = resumeFromKey {
        backfillLogger.info("🔄 BackfillJob: Resuming from last key: \(resumeKey)")
      }
      
      // Update migration state to started
      try await updateMigrationState(userId: userId, status: .running, startedAt: Date())
      
      // Get all local habits from SwiftData
      let localHabits = try await getLocalHabits()
      backfillLogger.info("📊 BackfillJob: Found \(localHabits.count) habits to migrate")
      status = "Found \(localHabits.count) habits to migrate"
      
      if localHabits.isEmpty {
        backfillLogger.info("ℹ️ BackfillJob: No habits found to migrate")
        status = "No habits to migrate"
        progress = 1.0
        try await updateMigrationState(userId: userId, status: .complete, finishedAt: Date())
        isRunning = false
        return
      }
      
      // Migrate habits in batches
      let totalBatches = (localHabits.count + batchSize - 1) / batchSize
      var processedCount = 0
      
      backfillLogger.info("🔢 BackfillJob: Migrating \(localHabits.count) habits in \(totalBatches) batches")
      
      for i in 0..<totalBatches {
        let startIndex = i * batchSize
        let endIndex = min(startIndex + batchSize, localHabits.count)
        let batch = Array(localHabits[startIndex..<endIndex])
        
        status = "Migrating batch \(i + 1)/\(totalBatches) (\(batch.count) habits)"
        backfillLogger.info("📦 BackfillJob: Processing batch \(i + 1)/\(totalBatches) (\(batch.count) habits)")
        
        try await migrateBatch(batch, userId: userId)
        
        processedCount += batch.count
        progress = Double(processedCount) / Double(localHabits.count)
        
        let currentProgress = self.progress
        backfillLogger.info("✅ BackfillJob: Batch \(i + 1)/\(totalBatches) complete. Progress: \(Int(currentProgress * 100))%")
        
        // Update last processed key (for resumability)
        try await updateMigrationState(
          userId: userId,
          status: .running,
          lastKey: batch.last?.id.uuidString
        )
      }
      
      // Mark migration as complete
      try await updateMigrationState(userId: userId, status: .complete, finishedAt: Date())
      
      status = "Migration complete! Migrated \(processedCount) habits"
      progress = 1.0
      
      backfillLogger.info("🎉 BackfillJob: Migration complete! Successfully migrated \(processedCount) habits to Firestore")
      
    } catch {
      self.error = error.localizedDescription
      status = "Migration failed: \(error.localizedDescription)"
      
      backfillLogger.error("❌ BackfillJob: Migration failed: \(error.localizedDescription)")
      
      // Update migration state with error (can be resumed later)
      if let userId = FirebaseConfiguration.currentUserId {
        try? await updateMigrationState(
          userId: userId,
          status: .failed,
          error: error.localizedDescription
        )
      }
    }
    
    isRunning = false
    backfillLogger.info("🏁 BackfillJob: Process completed")
  }
  
  // MARK: Private Methods
  
  private func getLocalHabits() async throws -> [Habit] {
    // Try SwiftData first (primary local storage)
    let swiftDataStorage = SwiftDataStorage()
    let swiftDataHabits = try await swiftDataStorage.loadHabits()
    
    if !swiftDataHabits.isEmpty {
      backfillLogger.info("📚 BackfillJob: Loaded \(swiftDataHabits.count) habits from SwiftData")
      return swiftDataHabits
    }
    
    // Fallback to UserDefaults if SwiftData is empty
    backfillLogger.info("📚 BackfillJob: SwiftData empty, checking UserDefaults...")
    let userDefaultsStorage = UserDefaultsStorage()
    let userDefaultsHabits = try await userDefaultsStorage.loadHabits()
    
    if !userDefaultsHabits.isEmpty {
      backfillLogger.info("📚 BackfillJob: Loaded \(userDefaultsHabits.count) habits from UserDefaults")
    }
    
    return userDefaultsHabits
  }
  
  private func migrateBatch(_ habits: [Habit], userId: String) async throws {
    let batch = db.batch()
    
    for habit in habits {
      let firestoreHabit = FirestoreHabit(from: habit)
      let habitData = firestoreHabit.toFirestoreData()
      
      let docRef = db.collection("users")
        .document(userId)
        .collection("habits")
        .document(habit.id.uuidString)
      
      batch.setData(habitData, forDocument: docRef, merge: true)
    }
    
    // Commit batch with retry logic
    try await commitBatchWithRetry(batch)
  }
  
  private func commitBatchWithRetry(_ batch: WriteBatch) async throws {
    var lastError: Error?
    let retries = self.maxRetries
    
    for attempt in 1...retries {
      do {
        try await batch.commit()
        backfillLogger.debug("✅ BackfillJob: Batch committed successfully on attempt \(attempt)")
        return
      } catch {
        lastError = error
        backfillLogger.warning("⚠️ BackfillJob: Batch commit attempt \(attempt)/\(retries) failed: \(error.localizedDescription)")
        
        if attempt < retries {
          // Exponential backoff
          let delay = pow(2.0, Double(attempt)) * 0.1
          backfillLogger.info("⏳ BackfillJob: Retrying in \(String(format: "%.1f", delay))s...")
          try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
      }
    }
    
    backfillLogger.error("❌ BackfillJob: All \(retries) batch commit attempts failed")
    throw lastError ?? BackfillError.batchCommitFailed
  }
  
  private func getMigrationState(userId: String) async throws -> FirebaseMigrationState {
    let docRef = db.collection("users")
      .document(userId)
      .collection("meta")
      .document("migration")
    
    let document = try await docRef.getDocument()
    
    if document.exists {
      return try document.data(as: FirebaseMigrationState.self)
    } else {
      return FirebaseMigrationState(status: .notStarted, lastKey: nil, startedAt: nil, finishedAt: nil, error: nil)
    }
  }
  
  private func updateMigrationState(
    userId: String,
    status: FirebaseMigrationState.Status,
    lastKey: String? = nil,
    startedAt: Date? = nil,
    finishedAt: Date? = nil,
    error: String? = nil
  ) async throws {
    let docRef = db.collection("users")
      .document(userId)
      .collection("meta")
      .document("migration")
    
    var data: [String: Any] = ["status": status.rawValue]
    
    if let lastKey = lastKey {
      data["lastKey"] = lastKey
    }
    if let startedAt = startedAt {
      data["startedAt"] = Timestamp(date: startedAt)
    }
    if let finishedAt = finishedAt {
      data["finishedAt"] = Timestamp(date: finishedAt)
    }
    if let error = error {
      data["error"] = error
    }
    
    try await docRef.setData(data, merge: true)
  }
}

// MARK: - MigrationState (using existing from Core/Models/MigrationState.swift)

// MARK: - BackfillError

enum BackfillError: LocalizedError {
  case notAuthenticated
  case batchCommitFailed
  case migrationInProgress
  
  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "User not authenticated"
    case .batchCommitFailed:
      return "Failed to commit batch to Firestore"
    case .migrationInProgress:
      return "Migration already in progress"
    }
  }
}

// MARK: - FirestoreHabit (using existing from Core/Models/FirestoreModels.swift)

// MARK: - Logging

private let backfillLogger = Logger(subsystem: "com.habitto.app", category: "BackfillJob")