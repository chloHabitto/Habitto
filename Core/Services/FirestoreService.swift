//
//  FirestoreService.swift
//  Habitto
//
//  Basic Firestore CRUD operations and real-time streaming
//

import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import SwiftUI

// MARK: - FirestoreError

enum FirestoreServiceError: Error, LocalizedError {
  case notConfigured
  case notAuthenticated
  case invalidData
  case documentNotFound
  case operationFailed(String)
  
  // MARK: Internal
  
  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "Firestore is not configured. Add GoogleService-Info.plist to your project."
    case .notAuthenticated:
      return "User is not authenticated. Please sign in first."
    case .invalidData:
      return "Invalid data format."
    case .documentNotFound:
      return "Document not found."
    case .operationFailed(let reason):
      return "Firestore operation failed: \(reason)"
    }
  }
}

// MARK: - FirestoreHabit (using existing from Core/Models/FirestoreModels.swift)

// MARK: - FirestoreService

/// Service for Firestore operations with real-time sync
class FirestoreService: FirebaseService, ObservableObject {
  // MARK: Lifecycle
  
  nonisolated private init() {
    print("📊 FirestoreService: Initialized")
    setupTelemetry()
  }
  
  // MARK: Internal
  
  nonisolated static let shared = FirestoreService()
  
  @MainActor @Published var habits: [Habit] = []
  @MainActor @Published var error: FirestoreServiceError?
  @MainActor @Published var isConnected = false
  
  // MARK: Private
  
  private var listener: ListenerRegistration?
  private var db: Firestore { Firestore.firestore() }
  
  // Telemetry counters
  nonisolated(unsafe) private var telemetryCounters: [String: Int] = [:]
  
  // MARK: - Habit Operations
  
  /// Create a new habit
  @MainActor
  func createHabit(_ habit: Habit) async throws -> Habit {
    print("📝 FirestoreService: Creating habit '\(habit.name)'")
    
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    let firestoreHabit = FirestoreHabit(from: habit)
    let habitData = firestoreHabit.toFirestoreData()
    
    try await db.collection("users")
      .document(userId)
      .collection("habits")
      .document(habit.id.uuidString)
      .setData(habitData, merge: true)
    
    // Update local cache
    habits.append(habit)
    
    // Record telemetry
    incrementCounter("dualwrite.create.primary_ok")
    
    print("✅ FirestoreService: Habit created with ID: \(habit.id.uuidString)")
    return habit
  }
  
  /// Update an existing habit
  @MainActor
  func updateHabit(_ habit: Habit) async throws {
    print("📝 FirestoreService: Updating habit \(habit.id.uuidString)")
    
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    let firestoreHabit = FirestoreHabit(from: habit)
    let habitData = firestoreHabit.toFirestoreData()
    
    try await db.collection("users")
      .document(userId)
      .collection("habits")
      .document(habit.id.uuidString)
      .setData(habitData, merge: true)
    
    // Update local cache
    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
      habits[index] = habit
    }
    
    // Record telemetry
    incrementCounter("dualwrite.update.primary_ok")
    
    print("✅ FirestoreService: Habit updated")
  }
  
  /// Delete a habit
  @MainActor
  func deleteHabit(id: String) async throws {
    print("🗑️ FirestoreService: Deleting habit \(id)")
    
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    try await db.collection("users")
      .document(userId)
      .collection("habits")
      .document(id)
      .delete()
    
    // Update local cache
    habits.removeAll { $0.id.uuidString == id }
    
    // Record telemetry
    incrementCounter("dualwrite.delete.primary_ok")
    
    print("✅ FirestoreService: Habit deleted")
  }
  
  /// Fetch all habits
  @MainActor
  func fetchHabits() async throws {
    print("📊 FirestoreService: Fetching habits")
    
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    let snapshot = try await db.collection("users")
      .document(userId)
      .collection("habits")
      .whereField("isActive", isEqualTo: true)
      .getDocuments()
    
    habits = snapshot.documents.compactMap { doc in
      do {
        let firestoreHabit = try doc.data(as: FirestoreHabit.self)
        return firestoreHabit.toHabit()
      } catch {
        print("❌ FirestoreService: Failed to decode habit \(doc.documentID): \(error)")
        return nil
      }
    }
    
    print("✅ FirestoreService: Fetched \(habits.count) habits")
  }
  
  /// Start listening to habit changes in real-time
  @MainActor
  func startListening() {
    print("👂 FirestoreService: Starting real-time listener")
    
    guard isConfigured else {
      print("⚠️ FirestoreService: Not configured")
      return
    }
    
    guard let userId = currentUserId else {
      print("⚠️ FirestoreService: Not authenticated")
      return
    }
    
    listener = db.collection("users")
      .document(userId)
      .collection("habits")
      .whereField("isActive", isEqualTo: true)
      .addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else { return }
        
        if let error = error {
          print("❌ FirestoreService: Listener error: \(error.localizedDescription)")
          Task { @MainActor in
            self.error = .operationFailed(error.localizedDescription)
          }
          return
        }
        
        guard let snapshot = snapshot else { return }
        
        Task { @MainActor in
          self.habits = snapshot.documents.compactMap { doc in
            do {
              let firestoreHabit = try doc.data(as: FirestoreHabit.self)
              return firestoreHabit.toHabit()
            } catch {
              print("❌ FirestoreService: Failed to decode habit \(doc.documentID): \(error)")
              return nil
            }
          }
          
          // Record telemetry
          self.incrementCounter("firestore.listener.events")
          
          print("✅ FirestoreService: Updated \(self.habits.count) habits from listener")
        }
      }
    
    print("✅ FirestoreService: Real-time listener started")
  }
  
  /// Stop listening to habit changes
  @MainActor
  func stopListening() {
    print("🛑 FirestoreService: Stopping real-time listener")
    listener?.remove()
    listener = nil
  }
  
  // MARK: - Telemetry
  
  nonisolated private func setupTelemetry() {
    telemetryCounters = [
      "dualwrite.create.primary_ok": 0,
      "dualwrite.update.primary_ok": 0,
      "dualwrite.delete.primary_ok": 0,
      "dualwrite.create.secondary_ok": 0,
      "dualwrite.update.secondary_ok": 0,
      "dualwrite.delete.secondary_ok": 0,
      "dualwrite.secondary_err": 0,
      "firestore.listener.events": 0
    ]
  }
  
  private func incrementCounter(_ key: String) {
    telemetryCounters[key, default: 0] += 1
  }
  
  func getTelemetryCounters() -> [String: Int] {
    return telemetryCounters
  }
  
  func logTelemetry() {
    print("📊 FirestoreService Telemetry:")
    for (key, value) in telemetryCounters.sorted(by: { $0.key < $1.key }) {
      print("  \(key): \(value)")
    }
  }
}

// MARK: - Color Extensions (using existing from Core/Utils/Design/ColorSystem.swift)

extension CodableColor {
  var hexString: String {
    let uiColor = UIColor(self.color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    
    let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255) << 0
    return String(format: "#%06x", rgb)
  }
}

