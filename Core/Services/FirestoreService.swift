//
//  FirestoreService.swift
//  Habitto
//
//  Basic Firestore CRUD operations and real-time streaming
//

import Combine
import FirebaseAuth
import FirebaseCore
// import FirebaseFirestore // Add after package is installed
import Foundation

// MARK: - FirestoreError

enum FirestoreError: Error, LocalizedError {
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

// MARK: - MockHabit

/// Mock habit model for demo purposes
struct MockHabit: Codable, Identifiable {
  var id: String
  var name: String
  var color: String
  var createdAt: Date
  var isActive: Bool
  
  init(id: String = UUID().uuidString, name: String, color: String, isActive: Bool = true) {
    self.id = id
    self.name = name
    self.color = color
    self.createdAt = Date()
    self.isActive = isActive
  }
}

// MARK: - FirestoreService

/// Service for Firestore operations
/// NOTE: This is a basic implementation. After adding FirebaseFirestore package,
/// uncomment the Firestore-specific code marked with /* ... */
class FirestoreService: FirebaseService, ObservableObject {
  // MARK: Lifecycle
  
  private init() {
    print("📊 FirestoreService: Initialized")
  }
  
  // MARK: Internal
  
  static let shared = FirestoreService()
  
  @MainActor @Published var habits: [MockHabit] = []
  @MainActor @Published var error: FirestoreError?
  
  // MARK: - Habit Operations (Mock Implementation)
  
  /// Create a new habit
  @MainActor
  func createHabit(name: String, color: String) async throws -> MockHabit {
    print("📝 FirestoreService: Creating habit '\(name)'")
    
    guard isConfigured else {
      print("⚠️ FirestoreService: Not configured, using mock data")
      let habit = MockHabit(name: name, color: color)
      habits.append(habit)
      return habit
    }
    
    guard currentUserId != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, use this code:
    let db = Firestore.firestore()
    let habitData: [String: Any] = [
      "name": name,
      "color": color,
      "createdAt": Timestamp(date: Date()),
      "isActive": true
    ]
    
    let docRef = try await db.collection("users").document(userId).collection("habits").addDocument(data: habitData)
    
    let habit = MockHabit(id: docRef.documentID, name: name, color: color)
    habits.append(habit)
    print("✅ FirestoreService: Habit created with ID: \(docRef.documentID)")
    return habit
    */
    
    // Mock implementation for now
    let habit = MockHabit(name: name, color: color)
    habits.append(habit)
    print("✅ FirestoreService: Mock habit created with ID: \(habit.id)")
    return habit
  }
  
  /// Update an existing habit
  @MainActor
  func updateHabit(id: String, name: String?, color: String?) async throws {
    print("📝 FirestoreService: Updating habit \(id)")
    
    guard isConfigured else {
      print("⚠️ FirestoreService: Not configured, updating mock data")
      if let index = habits.firstIndex(where: { $0.id == id }) {
        if let name = name {
          habits[index].name = name
        }
        if let color = color {
          habits[index].color = color
        }
      }
      return
    }
    
    guard currentUserId != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, use this code:
    let db = Firestore.firestore()
    var updateData: [String: Any] = [:]
    if let name = name {
      updateData["name"] = name
    }
    if let color = color {
      updateData["color"] = color
    }
    
    try await db.collection("users").document(userId).collection("habits").document(id).updateData(updateData)
    
    if let index = habits.firstIndex(where: { $0.id == id }) {
      if let name = name {
        habits[index].name = name
      }
      if let color = color {
        habits[index].color = color
      }
    }
    print("✅ FirestoreService: Habit updated")
    */
    
    // Mock implementation for now
    if let index = habits.firstIndex(where: { $0.id == id }) {
      if let name = name {
        habits[index].name = name
      }
      if let color = color {
        habits[index].color = color
      }
    }
    print("✅ FirestoreService: Mock habit updated")
  }
  
  /// Delete a habit
  @MainActor
  func deleteHabit(id: String) async throws {
    print("🗑️ FirestoreService: Deleting habit \(id)")
    
    guard isConfigured else {
      print("⚠️ FirestoreService: Not configured, deleting from mock data")
      habits.removeAll { $0.id == id }
      return
    }
    
    guard currentUserId != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, use this code:
    let db = Firestore.firestore()
    try await db.collection("users").document(userId).collection("habits").document(id).delete()
    habits.removeAll { $0.id == id }
    print("✅ FirestoreService: Habit deleted")
    */
    
    // Mock implementation for now
    habits.removeAll { $0.id == id }
    print("✅ FirestoreService: Mock habit deleted")
  }
  
  /// Fetch all habits
  @MainActor
  func fetchHabits() async throws {
    print("📊 FirestoreService: Fetching habits")
    
    guard isConfigured else {
      print("⚠️ FirestoreService: Not configured, using mock data")
      // Add some mock data for demonstration
      if habits.isEmpty {
        habits = [
          MockHabit(name: "Morning Run", color: "green"),
          MockHabit(name: "Read 30min", color: "blue"),
          MockHabit(name: "Meditate", color: "purple")
        ]
      }
      return
    }
    
    guard currentUserId != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, use this code:
    let db = Firestore.firestore()
    let snapshot = try await db.collection("users").document(userId).collection("habits")
      .whereField("isActive", isEqualTo: true)
      .getDocuments()
    
    habits = snapshot.documents.compactMap { doc in
      let data = doc.data()
      guard let name = data["name"] as? String,
            let color = data["color"] as? String,
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let isActive = data["isActive"] as? Bool else {
        return nil
      }
      return MockHabit(id: doc.documentID, name: name, color: color)
    }
    
    print("✅ FirestoreService: Fetched \(habits.count) habits")
    */
    
    // Mock implementation for now
    if habits.isEmpty {
      habits = [
        MockHabit(name: "Morning Run", color: "green"),
        MockHabit(name: "Read 30min", color: "blue"),
        MockHabit(name: "Meditate", color: "purple")
      ]
    }
    print("✅ FirestoreService: Fetched \(habits.count) mock habits")
  }
  
  /// Start listening to habit changes in real-time
  @MainActor
  func startListening() {
    print("👂 FirestoreService: Starting real-time listener")
    
    guard isConfigured else {
      print("⚠️ FirestoreService: Not configured, mock listener active")
      return
    }
    
    guard currentUserId != nil else {
      print("⚠️ FirestoreService: Not authenticated")
      return
    }
    
    /*
    // After adding FirebaseFirestore package, use this code:
    let db = Firestore.firestore()
    
    listener = db.collection("users").document(userId).collection("habits")
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
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let color = data["color"] as? String else {
              return nil
            }
            return MockHabit(id: doc.documentID, name: name, color: color)
          }
          print("✅ FirestoreService: Updated \(self.habits.count) habits from listener")
        }
      }
    */
    
    print("✅ FirestoreService: Mock listener started")
  }
  
  /// Stop listening to habit changes
  @MainActor
  func stopListening() {
    print("🛑 FirestoreService: Stopping real-time listener")
    /*
    listener?.remove()
    listener = nil
    */
  }
  
  // MARK: Private
  
  // private var listener: ListenerRegistration?
}

