//
//  DualWriteStorage.swift
//  Habitto
//
//  Dual-write storage that writes to both Firestore (primary) and local storage (secondary)
//

import Foundation
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
    
    // Secondary write (local storage) - non-blocking
    Task.detached { [weak self] in
      do {
        try await self?.secondaryStorage.saveHabits(habits, immediate: immediate)
        self?.incrementCounter("dualwrite.update.secondary_ok")
        print("✅ DualWriteStorage: Secondary write successful")
      } catch {
        self?.incrementCounter("dualwrite.secondary_err")
        print("❌ DualWriteStorage: Secondary write failed: \(error)")
      }
    }
  }
  
  func loadHabits() async throws -> [Habit] {
    dualWriteLogger.info("DualWriteStorage: Loading habits")
    
    // Try primary storage first (Firestore)
    do {
      try await primaryStorage.fetchHabits()
      let habits = await MainActor.run { primaryStorage.habits }
      dualWriteLogger.info("✅ DualWriteStorage: Loaded \(habits.count) habits from primary storage")
      return habits
    } catch {
      dualWriteLogger.warning("⚠️ DualWriteStorage: Primary load failed, falling back to secondary: \(error)")
      
      // Fallback to secondary storage
      let habits = try await secondaryStorage.loadHabits()
      dualWriteLogger.info("✅ DualWriteStorage: Loaded \(habits.count) habits from secondary storage")
      return habits
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
    
    // Secondary write (local storage) - non-blocking
    Task.detached { [weak self] in
      do {
        try await self?.secondaryStorage.saveHabit(habit, immediate: immediate)
        self?.incrementCounter("dualwrite.create.secondary_ok")
        print("✅ DualWriteStorage: Secondary write successful")
      } catch {
        self?.incrementCounter("dualwrite.secondary_err")
        print("❌ DualWriteStorage: Secondary write failed: \(error)")
      }
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
    
    // Secondary write (local storage) - non-blocking
    Task.detached { [weak self] in
      do {
        try await self?.secondaryStorage.deleteHabit(id: id)
        self?.incrementCounter("dualwrite.delete.secondary_ok")
        print("✅ DualWriteStorage: Secondary delete successful")
      } catch {
        self?.incrementCounter("dualwrite.secondary_err")
        print("❌ DualWriteStorage: Secondary delete failed: \(error)")
      }
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
    
    // Secondary write (local storage) - non-blocking
    Task.detached { [weak self] in
      do {
        try await self?.secondaryStorage.clearAllHabits()
        self?.incrementCounter("dualwrite.delete.secondary_ok")
        print("✅ DualWriteStorage: Secondary clear successful")
      } catch {
        self?.incrementCounter("dualwrite.secondary_err")
        print("❌ DualWriteStorage: Secondary clear failed: \(error)")
      }
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
}

// MARK: - Logging

let dualWriteLogger = Logger(subsystem: "com.habitto.app", category: "DualWriteStorage")
