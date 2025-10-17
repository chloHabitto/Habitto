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
    self.db = Firestore.firestore()
  }
  
  // MARK: Internal
  
  static let shared = BackfillJob()
  
  @Published var isRunning = false
  @Published var progress = 0.0
  @Published var status = "Ready"
  @Published var error: String?
  
  // MARK: Private
  
  private let db: Firestore
  private let batchSize = 450 // Firestore batch limit
  private let maxRetries = 3
  
  // MARK: - Public Methods
  
  /// Run backfill if enabled by feature flags
  func runIfEnabled() async {
    guard FeatureFlags.enableBackfill else {
      print("📊 BackfillJob: Backfill disabled by feature flag")
      return
    }
    
    await run()
  }
  
  /// Run the backfill process
  func run() async {
    guard !isRunning else {
      print("📊 BackfillJob: Already running")
      return
    }
    
    isRunning = true
    progress = 0.0
    status = "Starting backfill..."
    error = nil
    
    do {
      // Get current user ID
      guard let userId = FirebaseConfiguration.currentUserId else {
        throw BackfillError.notAuthenticated
      }
      
      // Check if migration is already complete
      let migrationState = try await getMigrationState(userId: userId)
      if migrationState.status == .complete {
        status = "Migration already complete"
        progress = 1.0
        isRunning = false
        return
      }
      
      // Update migration state to started
      try await updateMigrationState(userId: userId, status: .running, startedAt: Date())
      
      // Get all local habits
      let localHabits = try await getLocalHabits()
      status = "Found \(localHabits.count) habits to migrate"
      
      if localHabits.isEmpty {
        status = "No habits to migrate"
        progress = 1.0
        try await updateMigrationState(userId: userId, status: .complete, finishedAt: Date())
        isRunning = false
        return
      }
      
      // Migrate habits in batches
      let totalBatches = (localHabits.count + batchSize - 1) / batchSize
      var processedCount = 0
      
      for i in 0..<totalBatches {
        let startIndex = i * batchSize
        let endIndex = min(startIndex + batchSize, localHabits.count)
        let batch = Array(localHabits[startIndex..<endIndex])
        
        status = "Migrating batch \(i + 1)/\(totalBatches) (\(batch.count) habits)"
        
        try await migrateBatch(batch, userId: userId)
        
        processedCount += batch.count
        progress = Double(processedCount) / Double(localHabits.count)
        
        // Update last processed key
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
      
    } catch {
      self.error = error.localizedDescription
      status = "Migration failed: \(error.localizedDescription)"
      
      // Update migration state with error
      if let userId = FirebaseConfiguration.currentUserId {
        try? await updateMigrationState(
          userId: userId,
          status: .failed,
          error: error.localizedDescription
        )
      }
    }
    
    isRunning = false
  }
  
  // MARK: Private Methods
  
  private func getLocalHabits() async throws -> [Habit] {
    // Use the existing local storage to get habits
    // This would typically be UserDefaultsStorage or SwiftDataStorage
    let storage = UserDefaultsStorage()
    return try await storage.loadHabits()
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
    
    for attempt in 1...maxRetries {
      do {
        try await batch.commit()
        return
      } catch {
        lastError = error
        print("❌ BackfillJob: Batch commit attempt \(attempt) failed: \(error)")
        
        if attempt < maxRetries {
          // Exponential backoff
          let delay = pow(2.0, Double(attempt)) * 0.1
          try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
      }
    }
    
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