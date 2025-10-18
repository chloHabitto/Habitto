//
//  MigrationVerificationHelper.swift
//  Habitto
//
//  Helper for verifying and monitoring Firebase migration progress
//

import Foundation
import FirebaseFirestore
import OSLog

// MARK: - MigrationVerificationHelper

/// Helper for verifying and monitoring the Firebase migration process
@MainActor
final class MigrationVerificationHelper {
  // MARK: Lifecycle
  
  private init() {
    self.db = Firestore.firestore()
  }
  
  // MARK: Internal
  
  static let shared = MigrationVerificationHelper()
  
  // MARK: Private
  
  private let db: Firestore
  private let logger = Logger(subsystem: "com.habitto.app", category: "MigrationVerification")
  
  // MARK: - Verification Methods
  
  /// Get comprehensive migration status report
  func getMigrationReport() async -> MigrationReport {
    logger.info("📊 Generating migration report...")
    
    guard let userId = FirebaseConfiguration.currentUserId else {
      logger.error("❌ No authenticated user")
      return MigrationReport(
        userId: "unknown",
        isAuthenticated: false,
        migrationState: nil,
        localHabitCount: 0,
        firestoreHabitCount: 0,
        isComplete: false,
        errors: ["Not authenticated"]
      )
    }
    
    var errors: [String] = []
    
    // Get migration state from Firestore
    let migrationState = await getMigrationStateFromFirestore(userId: userId)
    
    // Count local habits
    let localCount = await getLocalHabitCount()
    
    // Count Firestore habits
    let firestoreCount = await getFirestoreHabitCount(userId: userId)
    
    // Check for mismatches
    if localCount > 0 && firestoreCount == 0 {
      errors.append("Local habits exist but Firestore is empty - migration may not have run")
    }
    
    if migrationState?.status == .failed {
      errors.append("Migration failed: \(migrationState?.error ?? "Unknown error")")
    }
    
    let isComplete = migrationState?.status == .complete && firestoreCount > 0
    
    let report = MigrationReport(
      userId: userId,
      isAuthenticated: true,
      migrationState: migrationState,
      localHabitCount: localCount,
      firestoreHabitCount: firestoreCount,
      isComplete: isComplete,
      errors: errors
    )
    
    return report
  }
  
  /// Print migration report to console
  func printMigrationReport() async {
    let report = await getMigrationReport()
    
    print("\n" + String(repeating: "=", count: 60))
    print("🔍 FIREBASE MIGRATION VERIFICATION REPORT")
    print(String(repeating: "=", count: 60))
    print("")
    
    print("👤 User ID: \(report.userId)")
    print("🔐 Authenticated: \(report.isAuthenticated ? "✅ Yes" : "❌ No")")
    print("")
    
    if let state = report.migrationState {
      print("📋 Migration State:")
      print("   Status: \(stateEmoji(for: state.status)) \(state.status.rawValue)")
      
      if let startedAt = state.startedAt {
        print("   Started: \(formatDate(startedAt))")
      }
      
      if let finishedAt = state.finishedAt {
        print("   Finished: \(formatDate(finishedAt))")
        if let started = state.startedAt {
          let duration = finishedAt.timeIntervalSince(started)
          print("   Duration: \(String(format: "%.1f", duration))s")
        }
      }
      
      if let lastKey = state.lastKey {
        print("   Last Key: \(lastKey)")
      }
      
      if let error = state.error {
        print("   ❌ Error: \(error)")
      }
    } else {
      print("📋 Migration State: ⚠️ Not found (migration not started)")
    }
    
    print("")
    print("📊 Habit Counts:")
    print("   Local (SwiftData/UserDefaults): \(report.localHabitCount)")
    print("   Firestore: \(report.firestoreHabitCount)")
    
    if report.localHabitCount == report.firestoreHabitCount && report.firestoreHabitCount > 0 {
      print("   ✅ Counts match - migration appears successful")
    } else if report.firestoreHabitCount > 0 && report.firestoreHabitCount < report.localHabitCount {
      print("   ⚠️ Partial migration - Firestore has fewer habits than local")
    } else if report.firestoreHabitCount > report.localHabitCount {
      print("   ⚠️ Firestore has more habits than local (possible multi-device sync)")
    }
    
    print("")
    print("🎯 Overall Status: \(report.isComplete ? "✅ COMPLETE" : "⚠️ INCOMPLETE")")
    
    if !report.errors.isEmpty {
      print("")
      print("❌ Issues Found:")
      for error in report.errors {
        print("   • \(error)")
      }
    }
    
    print("")
    print(String(repeating: "=", count: 60))
    print("")
  }
  
  /// Get detailed Firestore habit list
  func printFirestoreHabits() async {
    guard let userId = FirebaseConfiguration.currentUserId else {
      print("❌ Not authenticated")
      return
    }
    
    do {
      let snapshot = try await db.collection("users")
        .document(userId)
        .collection("habits")
        .getDocuments()
      
      print("\n📚 Firestore Habits (\(snapshot.documents.count) total):")
      print(String(repeating: "-", count: 60))
      
      for (index, doc) in snapshot.documents.enumerated() {
        let data = doc.data()
        let name = data["name"] as? String ?? "Unknown"
        let isActive = data["isActive"] as? Bool ?? false
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        
        print("\n\(index + 1). \(name)")
        print("   ID: \(doc.documentID)")
        print("   Active: \(isActive ? "✅" : "❌")")
        if let created = createdAt {
          print("   Created: \(formatDate(created))")
        }
      }
      
      print("\n" + String(repeating: "-", count: 60) + "\n")
      
    } catch {
      print("❌ Error fetching Firestore habits: \(error.localizedDescription)")
    }
  }
  
  /// Compare local vs Firestore habits
  func compareHabits() async {
    print("\n🔍 Comparing Local vs Firestore Habits...")
    print(String(repeating: "=", count: 60))
    
    // Get local habits
    let localHabits = await getLocalHabits()
    print("\n📱 Local Habits: \(localHabits.count)")
    
    // Get Firestore habits
    guard let userId = FirebaseConfiguration.currentUserId else {
      print("❌ Not authenticated")
      return
    }
    
    do {
      let snapshot = try await db.collection("users")
        .document(userId)
        .collection("habits")
        .getDocuments()
      
      let firestoreHabits = snapshot.documents.compactMap { doc -> (id: String, name: String)? in
        guard let name = doc.data()["name"] as? String else { return nil }
        return (doc.documentID, name)
      }
      
      print("☁️  Firestore Habits: \(firestoreHabits.count)")
      
      // Find habits only in local
      let localIds = Set(localHabits.map { $0.id.uuidString })
      let firestoreIds = Set(firestoreHabits.map { $0.id })
      
      let onlyLocal = localIds.subtracting(firestoreIds)
      let onlyFirestore = firestoreIds.subtracting(localIds)
      let inBoth = localIds.intersection(firestoreIds)
      
      print("\n📊 Comparison:")
      print("   In both: \(inBoth.count)")
      print("   Only local: \(onlyLocal.count)")
      print("   Only Firestore: \(onlyFirestore.count)")
      
      if !onlyLocal.isEmpty {
        print("\n⚠️ Habits only in local storage (not migrated):")
        for id in onlyLocal.prefix(5) {
          if let habit = localHabits.first(where: { $0.id.uuidString == id }) {
            print("   • \(habit.name) (\(id))")
          }
        }
        if onlyLocal.count > 5 {
          print("   ... and \(onlyLocal.count - 5) more")
        }
      }
      
      if !onlyFirestore.isEmpty {
        print("\n⚠️ Habits only in Firestore (not in local):")
        for id in onlyFirestore.prefix(5) {
          if let habit = firestoreHabits.first(where: { $0.id == id }) {
            print("   • \(habit.name) (\(id))")
          }
        }
        if onlyFirestore.count > 5 {
          print("   ... and \(onlyFirestore.count - 5) more")
        }
      }
      
      print("\n" + String(repeating: "=", count: 60) + "\n")
      
    } catch {
      print("❌ Error comparing habits: \(error.localizedDescription)")
    }
  }
  
  // MARK: - Private Helper Methods
  
  private func getMigrationStateFromFirestore(userId: String) async -> FirebaseMigrationState? {
    do {
      let docRef = db.collection("users")
        .document(userId)
        .collection("meta")
        .document("migration")
      
      let document = try await docRef.getDocument()
      
      if document.exists {
        return try document.data(as: FirebaseMigrationState.self)
      }
      return nil
      
    } catch {
      logger.error("Failed to get migration state: \(error.localizedDescription)")
      return nil
    }
  }
  
  private func getLocalHabitCount() async -> Int {
    let habits = await getLocalHabits()
    return habits.count
  }
  
  private func getLocalHabits() async -> [Habit] {
    do {
      // Try SwiftData first
      let swiftDataStorage = SwiftDataStorage()
      let swiftDataHabits = try await swiftDataStorage.loadHabits()
      
      if !swiftDataHabits.isEmpty {
        return swiftDataHabits
      }
      
      // Fallback to UserDefaults
      let userDefaultsStorage = UserDefaultsStorage()
      return try await userDefaultsStorage.loadHabits()
      
    } catch {
      logger.error("Failed to load local habits: \(error.localizedDescription)")
      return []
    }
  }
  
  private func getFirestoreHabitCount(userId: String) async -> Int {
    do {
      let snapshot = try await db.collection("users")
        .document(userId)
        .collection("habits")
        .getDocuments()
      
      return snapshot.documents.count
      
    } catch {
      logger.error("Failed to count Firestore habits: \(error.localizedDescription)")
      return 0
    }
  }
  
  private func stateEmoji(for status: FirebaseMigrationState.Status) -> String {
    switch status {
    case .notStarted: return "⏸️"
    case .running: return "🔄"
    case .complete: return "✅"
    case .failed: return "❌"
    }
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
}

// MARK: - MigrationReport

struct MigrationReport {
  let userId: String
  let isAuthenticated: Bool
  let migrationState: FirebaseMigrationState?
  let localHabitCount: Int
  let firestoreHabitCount: Int
  let isComplete: Bool
  let errors: [String]
}

// Note: FirebaseMigrationState is defined in Core/Models/MigrationState.swift

