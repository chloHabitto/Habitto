//
//  DualWriteStorage.swift
//  Habitto
//
//  Dual-write storage that writes to both Firestore (primary) and local storage (secondary)
//

import Foundation
import FirebaseFirestore
import OSLog

// MARK: - DualWriteStorage

/// Storage implementation that writes to both Firestore (primary) and local storage (secondary)
/// Uses non-blocking secondary writes to avoid UX delays
final class DualWriteStorage: HabitStorageProtocol {
  // MARK: Lifecycle
  
  init(
    primaryStorage: FirestoreService,
    secondaryStorage: any HabitStorageProtocol
  ) {
    self.primaryStorage = primaryStorage
    self.secondaryStorage = secondaryStorage
    self.telemetryCounters = [
      "dualwrite.create.primary_ok": 0,
      "dualwrite.update.primary_ok": 0,
      "dualwrite.delete.primary_ok": 0,
      "dualwrite.create.secondary_ok": 0,
      "dualwrite.update.secondary_ok": 0,
      "dualwrite.delete.secondary_ok": 0,
      "dualwrite.secondary_err": 0
    ]
  }
  
  // MARK: Internal
  
  typealias DataType = Habit
  
  // MARK: Private
  
  private let primaryStorage: FirestoreService
  private let secondaryStorage: any HabitStorageProtocol
  private var telemetryCounters: [String: Int]
  
  // MARK: - HabitStorageProtocol Implementation
  
  func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
    let taskId = UUID().uuidString.prefix(8)
    print("💾 SAVE_START[\(taskId)]: Saving \(habits.count) habits")
    for (i, habit) in habits.enumerated() {
      print("  [\(i)] '\(habit.name)' (id: \(habit.id.uuidString.prefix(8)), syncStatus: \(habit.syncStatus))")
    }
    
    dualWriteLogger.info("DualWriteStorage: Saving \(habits.count) habits")
    
    // ✅ PHASE 1: LOCAL-FIRST APPROACH
    // STEP 1: Write to local storage FIRST (fast, reliable, never blocks on network)
    let updatedHabits = habits.map { habit in
      var h = habit
      // Mark as pending if not already synced
      if h.syncStatus != .synced {
        h.syncStatus = .pending
      }
      return h
    }
    
    do {
      print("      ⏱️ DUALWRITE_SWIFTDATA_START: Calling secondaryStorage.saveHabits() at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))")
      try await secondaryStorage.saveHabits(updatedHabits, immediate: immediate)
      print("      ⏱️ DUALWRITE_SWIFTDATA_END: secondaryStorage.saveHabits() returned at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))")
      incrementCounter("dualwrite.update.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Local write successful (immediate)")
      print("✅ SAVE_LOCAL[\(taskId)]: Successfully saved to SwiftData")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Local write failed: \(error)")
      print("❌ SAVE_LOCAL[\(taskId)]: FAILED - \(error.localizedDescription)")
      print("❌ Error type: \(type(of: error))")
      print("❌ Full error: \(error)")
      throw error // MUST throw - local storage is primary
    }
    
    // STEP 2: Sync to Firestore in BACKGROUND (non-blocking, won't slow down UI)
    print("🚀 SAVE_BACKGROUND[\(taskId)]: Launching background sync task...")
    Task.detached { [weak self, primaryStorage] in
      let selfStatus = self != nil ? "alive" : "NIL!"
      print("📤 SYNC_START[\(taskId)]: Background task running, self=\(selfStatus)")
      if self == nil {
        print("❌ SYNC_FATAL[\(taskId)]: self is NIL! Sync will be skipped!")
      }
      await self?.syncHabitsToFirestore(habits: updatedHabits, primaryStorage: primaryStorage)
      print("✅ SYNC_END[\(taskId)]: Background task complete")
    }
    
    print("✅ SAVE_COMPLETE[\(taskId)]: Returning to caller (background task still running)")
  }
  
  /// Background sync to Firestore (non-blocking)
  private func syncHabitsToFirestore(
    habits: [Habit],
    primaryStorage: FirestoreService
  ) async {
    print("📤 SYNC_FIRESTORE: Processing \(habits.count) habits")
    dualWriteLogger.info("📤 DualWriteStorage: Starting background sync for \(habits.count) habits")
    
    var syncedCount = 0
    var skippedCount = 0
    var failedCount = 0
    
    for var habit in habits {
      print("  → Checking '\(habit.name)' (syncStatus: \(habit.syncStatus), lastSynced: \(habit.lastSyncedAt?.description ?? "never"))")
      
      // Skip if already synced (optimization)
      if habit.syncStatus == .synced, habit.lastSyncedAt != nil {
        let timeSinceSync = Date().timeIntervalSince(habit.lastSyncedAt!)
        if timeSinceSync < 60 { // Less than 1 minute since last sync
          print("  ⏭️ SKIP: '\(habit.name)' was synced \(Int(timeSinceSync))s ago")
          skippedCount += 1
          continue
        }
      }
      
      habit.syncStatus = .syncing
      print("  📤 SYNCING: '\(habit.name)' to Firestore...")
      
      do {
        _ = try await primaryStorage.createHabit(habit)
        habit.syncStatus = .synced
        habit.lastSyncedAt = Date()
        
        // Update local storage with new sync status
        do {
          try await secondaryStorage.saveHabit(habit, immediate: false)
          print("  ✅ SUCCESS: '\(habit.name)' synced and status updated")
        } catch {
          print("  ⚠️ WARNING: '\(habit.name)' synced but failed to update local status: \(error)")
        }
        
        incrementCounter("dualwrite.update.primary_ok")
        dualWriteLogger.info("✅ Synced '\(habit.name)' to Firestore")
        syncedCount += 1
        
      } catch {
        habit.syncStatus = .failed
        
        // Update local storage with failed status
        do {
          try await secondaryStorage.saveHabit(habit, immediate: false)
          print("  ❌ FAILED: '\(habit.name)' sync failed, error saved: \(error)")
        } catch let updateError {
          print("  ❌ CRITICAL: '\(habit.name)' sync failed AND couldn't save error state!")
          print("     Sync error: \(error)")
          print("     Update error: \(updateError)")
        }
        
        dualWriteLogger.error("❌ Firestore sync failed for '\(habit.name)': \(error)")
        failedCount += 1
        // TODO: Add to retry queue
      }
    }
    
    print("📤 SYNC_COMPLETE: synced=\(syncedCount), skipped=\(skippedCount), failed=\(failedCount)")
    dualWriteLogger.info("📤 DualWriteStorage: Background sync complete (synced=\(syncedCount), failed=\(failedCount))")
  }
  
  func loadHabits() async throws -> [Habit] {
    dualWriteLogger.info("DualWriteStorage: Loading habits")
    
    // CRITICAL: Check migration status first
    // If migration hasn't completed, ALWAYS use local storage
    let migrationComplete = await checkMigrationComplete()
    
    if !migrationComplete {
      dualWriteLogger.info("⚠️ DualWriteStorage: Migration not complete, using local storage")
      let habits = try await secondaryStorage.loadHabits()
      let filtered = filterCorruptedHabits(habits)
      dualWriteLogger.info("✅ DualWriteStorage: Loaded \(filtered.count) habits from local storage (pre-migration)")
      return filtered
    }
    
    // Try primary storage first (Firestore) only after migration is complete
    do {
      try await primaryStorage.fetchHabits()
      let habits = await MainActor.run { primaryStorage.habits }
      
      // If Firestore is empty but we haven't disabled legacy fallback, check local storage
      // TODO: Implement proper FeatureFlags.enableLegacyReadFallback
      if habits.isEmpty && true {
        dualWriteLogger.info("⚠️ DualWriteStorage: Firestore empty, checking local storage...")
        let localHabits = try await secondaryStorage.loadHabits()
        if !localHabits.isEmpty {
          let filtered = filterCorruptedHabits(localHabits)
          dualWriteLogger.info("✅ DualWriteStorage: Found \(filtered.count) habits in local storage, using those")
          return filtered
        }
      }
      
      dualWriteLogger.info("✅ DualWriteStorage: Loaded \(habits.count) habits from Firestore")
      return habits
    } catch {
      dualWriteLogger.warning("⚠️ DualWriteStorage: Firestore load failed, falling back to local: \(error)")
      
      // Fallback to secondary storage
      let habits = try await secondaryStorage.loadHabits()
      let filtered = filterCorruptedHabits(habits)
      dualWriteLogger.info("✅ DualWriteStorage: Loaded \(filtered.count) habits from local storage (fallback)")
      return filtered
    }
  }
  
  /// Check if migration to Firestore is complete
  private func checkMigrationComplete() async -> Bool {
    let userId = await MainActor.run { FirebaseConfiguration.currentUserId }
    guard let userId = userId else {
      return false
    }
    
    do {
      let docRef = Firestore.firestore()
        .collection("users")
        .document(userId)
        .collection("meta")
        .document("migration")
      
      let document = try await docRef.getDocument()
      
      if let data = document.data(),
         let status = data["status"] as? String {
        return status == "complete"
      }
      
      return false
    } catch {
      dualWriteLogger.warning("Failed to check migration status: \(error)")
      return false
    }
  }
  
  func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
    dualWriteLogger.info("DualWriteStorage: Saving habit '\(habit.name)'")
    
    // ✅ PHASE 1: LOCAL-FIRST APPROACH
    // STEP 1: Write to local storage FIRST
    var updatedHabit = habit
    if updatedHabit.syncStatus != .synced {
      updatedHabit.syncStatus = .pending
    }
    
    do {
      try await secondaryStorage.saveHabit(updatedHabit, immediate: immediate)
      incrementCounter("dualwrite.create.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Local write successful for '\(habit.name)'")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Local write failed for '\(habit.name)': \(error)")
      throw error // MUST throw - local storage is primary
    }
    
    // STEP 2: Sync to Firestore in BACKGROUND
    Task.detached { [weak self, primaryStorage] in
      await self?.syncHabitToFirestore(habit: updatedHabit, primaryStorage: primaryStorage)
    }
  }
  
  /// Background sync single habit to Firestore (non-blocking)
  private func syncHabitToFirestore(
    habit: Habit,
    primaryStorage: FirestoreService
  ) async {
    var updatedHabit = habit
    updatedHabit.syncStatus = .syncing
    
    do {
      _ = try await primaryStorage.createHabit(updatedHabit)
      updatedHabit.syncStatus = .synced
      updatedHabit.lastSyncedAt = Date()
      
      // Update local storage with new sync status
      try? await secondaryStorage.saveHabit(updatedHabit, immediate: false)
      
      incrementCounter("dualwrite.create.primary_ok")
      dualWriteLogger.info("✅ Synced habit '\(habit.name)' to Firestore")
      
    } catch {
      updatedHabit.syncStatus = .failed
      
      // Update local storage with failed status
      try? await secondaryStorage.saveHabit(updatedHabit, immediate: false)
      
      dualWriteLogger.error("❌ Firestore sync failed for '\(habit.name)': \(error)")
      // TODO: Add to retry queue
    }
  }
  
  func deleteHabit(id: UUID) async throws {
    dualWriteLogger.info("DualWriteStorage: Deleting habit \(id)")
    
    // ✅ PHASE 1: LOCAL-FIRST APPROACH
    // STEP 1: Delete from local storage FIRST
    do {
      try await secondaryStorage.deleteHabit(id: id)
      incrementCounter("dualwrite.delete.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Local delete successful")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Local delete failed: \(error)")
      throw error // MUST throw - local storage is primary
    }
    
    // STEP 2: Delete from Firestore in BACKGROUND
    Task.detached { [weak self, primaryStorage] in
      await self?.deleteHabitFromFirestore(id: id, primaryStorage: primaryStorage)
    }
  }
  
  /// Background delete from Firestore (non-blocking)
  private func deleteHabitFromFirestore(
    id: UUID,
    primaryStorage: FirestoreService
  ) async {
    do {
      try await primaryStorage.deleteHabit(id: id.uuidString)
      incrementCounter("dualwrite.delete.primary_ok")
      dualWriteLogger.info("✅ Deleted habit \(id) from Firestore")
    } catch {
      dualWriteLogger.error("❌ Firestore delete failed for \(id): \(error)")
      // TODO: Add to retry queue
    }
  }
  
  func clearAllHabits() async throws {
    dualWriteLogger.info("DualWriteStorage: Clearing all habits")
    
    // ✅ PHASE 1: LOCAL-FIRST APPROACH
    // STEP 1: Clear local storage FIRST
    do {
      try await secondaryStorage.clearAllHabits()
      incrementCounter("dualwrite.delete.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Local clear successful")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Local clear failed: \(error)")
      throw error // MUST throw - local storage is primary
    }
    
    // STEP 2: Clear Firestore in BACKGROUND
    Task.detached { [weak self, primaryStorage] in
      await self?.clearFirestoreHabits(primaryStorage: primaryStorage)
    }
  }
  
  /// Background clear from Firestore (non-blocking)
  private func clearFirestoreHabits(primaryStorage: FirestoreService) async {
    do {
      // Delete all habits from Firestore
      try await primaryStorage.fetchHabits()
      let habits = await MainActor.run { primaryStorage.habits }
      for habit in habits {
        try await primaryStorage.deleteHabit(id: habit.id.uuidString)
      }
      incrementCounter("dualwrite.delete.primary_ok")
      dualWriteLogger.info("✅ Cleared all habits from Firestore")
    } catch {
      dualWriteLogger.error("❌ Firestore clear failed: \(error)")
      // TODO: Add to retry queue
    }
  }
  
  func loadHabit(id: UUID) async throws -> Habit? {
    dualWriteLogger.info("DualWriteStorage: Loading habit \(id)")
    
    // Try primary storage first (Firestore)
    do {
      try await primaryStorage.fetchHabits()
      let habits = await MainActor.run { primaryStorage.habits }
      let habit = habits.first { $0.id == id }
      dualWriteLogger.info("✅ DualWriteStorage: Loaded habit from primary storage")
      return habit
    } catch {
      dualWriteLogger.warning("⚠️ DualWriteStorage: Primary load failed, falling back to secondary: \(error)")
      
      // Fallback to secondary storage
      let habit = try await secondaryStorage.loadHabit(id: id)
      dualWriteLogger.info("✅ DualWriteStorage: Loaded habit from secondary storage")
      return habit
    }
  }
  
  // MARK: - Generic Data Storage Methods
  
  func save(_ data: some Codable, forKey key: String, immediate: Bool = false) async throws {
    // For generic data, only use secondary storage
    try await secondaryStorage.save(data, forKey: key, immediate: immediate)
  }
  
  func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
    // For generic data, only use secondary storage
    return try await secondaryStorage.load(type, forKey: key)
  }
  
  func delete(forKey key: String) async throws {
    // For generic data, only use secondary storage
    try await secondaryStorage.delete(forKey: key)
  }
  
  func exists(forKey key: String) async throws -> Bool {
    // For generic data, only use secondary storage
    return try await secondaryStorage.exists(forKey: key)
  }
  
  func keys(withPrefix prefix: String) async throws -> [String] {
    // For generic data, only use secondary storage
    return try await secondaryStorage.keys(withPrefix: prefix)
  }
  
  // MARK: - Telemetry
  
  private func incrementCounter(_ key: String) {
    telemetryCounters[key, default: 0] += 1
  }
  
  func getTelemetryCounters() -> [String: Int] {
    return telemetryCounters
  }
  
  func logTelemetry() {
    dualWriteLogger.info("📊 DualWriteStorage Telemetry:")
    for (key, value) in telemetryCounters.sorted(by: { $0.key < $1.key }) {
      dualWriteLogger.info("  \(key): \(value)")
    }
  }
  
  // ✅ Simple validation: only skip habits with invalid data that would cause crashes
  private func filterCorruptedHabits(_ habits: [Habit]) -> [Habit] {
    let filtered = habits.filter { habit in
      // Skip breaking habits with invalid target/baseline (this is a real validation error)
      if habit.habitType == .breaking {
        let isValid = habit.target < habit.baseline && habit.baseline > 0
        if !isValid {
          dualWriteLogger.warning("⚠️ SKIPPING INVALID BREAKING HABIT: '\(habit.name)' (target=\(habit.target), baseline=\(habit.baseline))")
          return false
        }
      }
      return true
    }
    
    let skippedCount = habits.count - filtered.count
    if skippedCount > 0 {
      dualWriteLogger.warning("⚠️ Filtered out \(skippedCount) invalid habit(s)")
    }
    
    return filtered
  }
}

// MARK: - Logging

let dualWriteLogger = Logger(subsystem: "com.habitto.app", category: "DualWriteStorage")
