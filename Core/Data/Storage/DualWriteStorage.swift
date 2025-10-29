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
    // ✅ CRITICAL FIX: Use regular Task (not detached) with strong capture to prevent self=NIL
    print("🚀 SAVE_BACKGROUND[\(taskId)]: Launching background sync task...")
    Task { [self, primaryStorage] in
      print("📤 SYNC_START[\(taskId)]: Background task running, self captured")
      await self.syncHabitsToFirestore(habits: updatedHabits, primaryStorage: primaryStorage)
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
    // ✅ CRITICAL FIX: LOCAL-FIRST ARCHITECTURE
    // Always load from SwiftData (fast, reliable, local)
    // Firestore is for background sync only, NOT the source of truth
    dualWriteLogger.info("DualWriteStorage: Loading habits from local storage (local-first)")
    print("📂 LOAD: Using local-first strategy - loading from SwiftData")
    
    do {
      let habits = try await secondaryStorage.loadHabits()
      let filtered = filterCorruptedHabits(habits)
      
      // ✅ NEW: If local storage is empty, try to sync down from Firestore
      if filtered.isEmpty {
        print("📂 LOAD: Local storage is empty, attempting to sync from Firestore...")
        dualWriteLogger.info("⚠️ DualWriteStorage: Local storage empty, attempting Firestore sync")
        
        do {
          // Fetch habits from Firestore
          try await primaryStorage.fetchHabits()
          let firestoreHabits = await MainActor.run { primaryStorage.habits }
          
          if !firestoreHabits.isEmpty {
            print("📥 SYNC_DOWN: Found \(firestoreHabits.count) habits in Firestore, saving to local...")
            dualWriteLogger.info("📥 Syncing down \(firestoreHabits.count) habits from Firestore")
            
            // Save to local storage
            try await secondaryStorage.saveHabits(firestoreHabits, immediate: true)
            
            let syncedFiltered = filterCorruptedHabits(firestoreHabits)
            print("✅ SYNC_DOWN: Successfully synced \(syncedFiltered.count) habits from Firestore")
            dualWriteLogger.info("✅ Successfully synced \(syncedFiltered.count) habits from Firestore to local")
            return syncedFiltered
          } else {
            print("📂 LOAD: No habits found in Firestore either - fresh install")
            dualWriteLogger.info("📂 No habits in Firestore - fresh install")
          }
        } catch {
          print("⚠️ SYNC_DOWN: Failed to sync from Firestore: \(error)")
          dualWriteLogger.warning("⚠️ Failed to sync from Firestore: \(error.localizedDescription)")
          // Don't throw - just return empty array if Firestore sync fails
        }
      }
      
      dualWriteLogger.info("✅ DualWriteStorage: Loaded \(filtered.count) habits from local storage")
      print("✅ LOAD: Loaded \(filtered.count) habits from SwiftData successfully")
      return filtered
    } catch {
      dualWriteLogger.error("❌ DualWriteStorage: Local load failed: \(error)")
      print("❌ LOAD_FAILED: SwiftData load error: \(error)")
      throw error
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
    print("🗑️ DELETE_START: DualWriteStorage.deleteHabit() called for ID: \(id)")
    dualWriteLogger.info("DualWriteStorage: Deleting habit \(id)")
    
    // ✅ CRITICAL FIX: Delete from Firestore FIRST to prevent re-sync
    // STEP 1: Delete from Firestore (synchronous, must complete)
    print("🗑️ DELETE_FIRESTORE_START: Attempting Firestore deletion...")
    do {
      try await primaryStorage.deleteHabit(id: id.uuidString)
      incrementCounter("dualwrite.delete.primary_ok")
      print("✅ DELETE_FIRESTORE_SUCCESS: Habit deleted from Firestore")
      dualWriteLogger.info("✅ DualWriteStorage: Firestore delete successful")
    } catch {
      incrementCounter("dualwrite.primary_err")
      print("❌ DELETE_FIRESTORE_FAILED: \(error.localizedDescription)")
      dualWriteLogger.error("❌ Firestore delete failed: \(error)")
      // ⚠️ CRITICAL: If Firestore delete fails, still continue with local delete
      // Otherwise the habit will be stuck (local has it, Firestore has it, can't delete)
      print("⚠️ DELETE_WARNING: Continuing with local delete despite Firestore failure")
    }
    
    // STEP 2: Delete from local storage (always execute)
    print("🗑️ DELETE_LOCAL_START: Attempting SwiftData deletion...")
    do {
      try await secondaryStorage.deleteHabit(id: id)
      incrementCounter("dualwrite.delete.secondary_ok")
      print("✅ DELETE_LOCAL_SUCCESS: Habit deleted from SwiftData")
      dualWriteLogger.info("✅ DualWriteStorage: Local delete successful")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      print("❌ DELETE_LOCAL_FAILED: \(error.localizedDescription)")
      dualWriteLogger.error("❌ CRITICAL: Local delete failed: \(error)")
      throw error // MUST throw - local storage is critical
    }
    
    print("✅ DELETE_COMPLETE: Habit deletion completed successfully")
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
    
    // ✅ STEP 1: Clear local storage FIRST
    do {
      try await secondaryStorage.clearAllHabits()
      incrementCounter("dualwrite.delete.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Local clear successful")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Local clear failed: \(error)")
      throw error // MUST throw - local storage is primary
    }
    
    // ✅ STEP 2: Clear Firestore SYNCHRONOUSLY (await to ensure deletion completes)
    // This prevents sync-down from restoring deleted data
    await clearFirestoreHabits(primaryStorage: primaryStorage)
  }
  
  /// Clear all habits from Firestore (synchronous)
  private func clearFirestoreHabits(primaryStorage: FirestoreService) async {
    do {
      print("🔥 DELETE_ALL: Starting Firestore habits deletion...")
      // Delete all habits from Firestore
      try await primaryStorage.fetchHabits()
      let habits = await MainActor.run { primaryStorage.habits }
      
      if habits.isEmpty {
        print("✅ DELETE_ALL: No habits in Firestore to delete")
        return
      }
      
      print("🔥 DELETE_ALL: Deleting \(habits.count) habits from Firestore...")
      for habit in habits {
        try await primaryStorage.deleteHabit(id: habit.id.uuidString)
      }
      incrementCounter("dualwrite.delete.primary_ok")
      dualWriteLogger.info("✅ Cleared all habits from Firestore")
      print("✅ DELETE_ALL: Successfully deleted all \(habits.count) habits from Firestore")
    } catch {
      dualWriteLogger.error("❌ Firestore clear failed: \(error)")
      print("❌ DELETE_ALL: Firestore habits deletion failed: \(error)")
      // Don't throw - local deletion already succeeded
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
