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
    dualWriteLogger.info("DualWriteStorage: Saving \(habits.count) habits")
    
    // Primary write (Firestore) - blocking
    do {
      // Update Firestore with all habits
      for habit in habits {
        _ = try await primaryStorage.createHabit(habit)
      }
      incrementCounter("dualwrite.update.primary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Primary write successful")
    } catch {
      dualWriteLogger.error("❌ DualWriteStorage: Primary write failed: \(error)")
      throw error
    }
    
    // ✅ FIX #22: Secondary write (local storage) - NOW BLOCKING for data safety
    // Changed from Task.detached (fire-and-forget) to await (blocking)
    // This ensures local data is saved successfully before continuing
    do {
      try await secondaryStorage.saveHabits(habits, immediate: immediate)
      incrementCounter("dualwrite.update.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Secondary (local) write successful")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Secondary (local) write failed: \(error)")
      // Don't throw - primary (cloud) write succeeded, so don't fail the entire operation
      // But log it as critical since local data is our backup
    }
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
    
    // Primary write (Firestore) - blocking
    do {
      _ = try await primaryStorage.createHabit(habit)
      incrementCounter("dualwrite.create.primary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Primary write successful")
    } catch {
      dualWriteLogger.error("❌ DualWriteStorage: Primary write failed: \(error)")
      throw error
    }
    
    // ✅ FIX #22: Secondary write (local storage) - NOW BLOCKING for data safety
    do {
      try await secondaryStorage.saveHabit(habit, immediate: immediate)
      incrementCounter("dualwrite.create.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Secondary (local) write successful")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Secondary (local) write failed: \(error)")
      // Don't throw - primary (cloud) write succeeded
    }
  }
  
  func deleteHabit(id: UUID) async throws {
    dualWriteLogger.info("DualWriteStorage: Deleting habit \(id)")
    
    // Primary write (Firestore) - blocking
    do {
      try await primaryStorage.deleteHabit(id: id.uuidString)
      incrementCounter("dualwrite.delete.primary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Primary delete successful")
    } catch {
      dualWriteLogger.error("❌ DualWriteStorage: Primary delete failed: \(error)")
      throw error
    }
    
    // ✅ FIX #22: Secondary delete (local storage) - NOW BLOCKING for data safety
    do {
      try await secondaryStorage.deleteHabit(id: id)
      incrementCounter("dualwrite.delete.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Secondary (local) delete successful")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Secondary (local) delete failed: \(error)")
      // Don't throw - primary (cloud) delete succeeded
    }
  }
  
  func clearAllHabits() async throws {
    dualWriteLogger.info("DualWriteStorage: Clearing all habits")
    
    // Primary write (Firestore) - blocking
    do {
      // Delete all habits from Firestore
      try await primaryStorage.fetchHabits()
      let habits = await MainActor.run { primaryStorage.habits }
      for habit in habits {
        try await primaryStorage.deleteHabit(id: habit.id.uuidString)
      }
      incrementCounter("dualwrite.delete.primary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Primary clear successful")
    } catch {
      dualWriteLogger.error("❌ DualWriteStorage: Primary clear failed: \(error)")
      throw error
    }
    
    // ✅ FIX #22: Secondary clear (local storage) - NOW BLOCKING for data safety
    do {
      try await secondaryStorage.clearAllHabits()
      incrementCounter("dualwrite.delete.secondary_ok")
      dualWriteLogger.info("✅ DualWriteStorage: Secondary (local) clear successful")
    } catch {
      incrementCounter("dualwrite.secondary_err")
      dualWriteLogger.error("❌ CRITICAL: Secondary (local) clear failed: \(error)")
      // Don't throw - primary (cloud) clear succeeded
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
