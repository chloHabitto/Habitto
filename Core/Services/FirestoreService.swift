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
    FirebaseBootstrapper.configureIfNeeded(source: "FirestoreService.init")
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
    
    return habit
  }
  
  /// Update an existing habit
  @MainActor
  func updateHabit(_ habit: Habit) async throws {
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
  }
  
  /// Delete a habit
  @MainActor
  func deleteHabit(id: String) async throws {
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
  }
  
  /// Fetch all habits
  @MainActor
  func fetchHabits() async throws {
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
    
    let fetchedHabits = snapshot.documents.compactMap { doc in
      do {
        let firestoreHabit = try doc.data(as: FirestoreHabit.self)
        return firestoreHabit.toHabit()
      } catch {
        print("❌ Failed to decode habit \(doc.documentID): \(error)")
        return nil
      }
    }
    
    // ✅ Simple validation: only skip habits with invalid data that would cause crashes
    habits = fetchedHabits.filter { habit in
      // Skip breaking habits with invalid target/baseline (this is a real validation error)
      if habit.habitType == .breaking {
        let isValid = habit.target < habit.baseline && habit.baseline > 0
        if !isValid {
          print("⚠️ Skipping invalid breaking habit: '\(habit.name)'")
          return false
        }
      }
      return true
    }
  }
  
  /// Start listening to habit changes in real-time
  @MainActor
  func startListening() {
    guard isConfigured else {
      return
    }
    
    guard let userId = currentUserId else {
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
          let fetchedHabits = snapshot.documents.compactMap { doc in
            do {
              let firestoreHabit = try doc.data(as: FirestoreHabit.self)
              return firestoreHabit.toHabit()
            } catch {
              print("❌ Failed to decode habit \(doc.documentID): \(error)")
              return nil
            }
          }
          
          // ✅ Simple validation: only skip habits with invalid data that would cause crashes
          self.habits = fetchedHabits.filter { habit in
            // Skip breaking habits with invalid target/baseline (this is a real validation error)
            if habit.habitType == .breaking {
              let isValid = habit.target < habit.baseline && habit.baseline > 0
              if !isValid {
                return false
              }
            }
            return true
          }
          
          // Record telemetry
          self.incrementCounter("firestore.listener.events")
        }
      }
  }
  
  /// Stop listening to habit changes
  @MainActor
  func stopListening() {
    listener?.remove()
    listener = nil
  }
  
  // MARK: - XP & Progress Operations
  
  /// Save user's current progress (total XP, level, etc.)
  @MainActor
  func saveUserProgress(_ progress: FirestoreUserProgress) async throws {
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    let progressData = progress.toFirestoreData()
    
    // Use transaction to prevent race conditions
    let docRef = db.collection("users")
      .document(userId)
      .collection("progress")
      .document("current")
    
    // ✅ FIX: Explicitly discard transaction result to silence warning
    _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
      let snapshot: DocumentSnapshot
      do {
        snapshot = try transaction.getDocument(docRef)
      } catch let error as NSError {
        errorPointer?.pointee = error
        return nil
      }
      
      // Check if we should update (use latest timestamp)
      if let existingData = snapshot.data(),
         let existingTimestamp = existingData["lastUpdated"] as? Timestamp {
        let existingDate = existingTimestamp.dateValue()
        
        // Only update if new data is more recent
        if progress.lastUpdated <= existingDate {
          return nil
        }
      }
      
      transaction.setData(progressData, forDocument: docRef)
      return nil
    })
  }
  
  /// Load user's current progress
  @MainActor
  func loadUserProgress() async throws -> FirestoreUserProgress? {
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    let snapshot = try await db.collection("users")
      .document(userId)
      .collection("progress")
      .document("current")
      .getDocument()
    
    guard snapshot.exists, let data = snapshot.data() else {
      return nil
    }
    
    let progress = FirestoreUserProgress.from(data: data)
    return progress
  }
  
  /// Delete all user's progress and XP data from Firestore
  @MainActor
  func deleteUserProgress() async throws {
    guard isConfigured else {
      return
    }
    
    guard let userId = currentUserId else {
      return
    }
    
    do {
      // Delete all documents in the progress collection
      // This includes the "current" document and any other progress data
      let progressCollection = db.collection("users")
        .document(userId)
        .collection("progress")
      
      // Get all documents in the progress collection
      let snapshot = try await progressCollection.getDocuments()
      
      for document in snapshot.documents {
        try await document.reference.delete()
      }
      
      // Note: Subcollections under documents (like daily_awards subcollections)
      // are not automatically deleted and would need to be deleted separately
      // For now, we're deleting the main progress documents which is the critical data
    } catch {
      print("❌ Firestore XP deletion failed: \(error)")
      // Don't throw - we want to continue even if Firestore deletion fails
    }
  }
  
  /// Save a daily award
  @MainActor
  func saveDailyAward(_ award: FirestoreDailyAward) async throws {
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    // Parse date to extract year-month and day
    // Format: "YYYY-MM-DD" -> month: "YYYY-MM", day: "DD"
    let components = award.date.split(separator: "-")
    guard components.count == 3 else {
      throw FirestoreServiceError.invalidData
    }
    
    let yearMonth = "\(components[0])-\(components[1])" // "YYYY-MM"
    let day = String(components[2]) // "DD"
    
    let awardData = award.toFirestoreData()
    
    // Path: /users/{uid}/progress/daily_awards/{YYYY-MM}/{DD}
    try await db.collection("users")
      .document(userId)
      .collection("progress")
      .document("daily_awards")
      .collection(yearMonth)
      .document(day)
      .setData(awardData)
  }
  
  /// Load daily awards for a specific month
  @MainActor
  func loadDailyAwards(yearMonth: String) async throws -> [FirestoreDailyAward] {
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    let snapshot = try await db.collection("users")
      .document(userId)
      .collection("progress")
      .document("daily_awards")
      .collection(yearMonth)
      .getDocuments()
    
    let awards = snapshot.documents.compactMap { doc -> FirestoreDailyAward? in
      FirestoreDailyAward.from(data: doc.data())
    }
    
    return awards
  }
  
  /// Load daily awards for a date range
  @MainActor
  func loadDailyAwards(from startDate: Date, to endDate: Date) async throws -> [FirestoreDailyAward] {
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    
    // Get all unique year-months in the range
    var yearMonths: Set<String> = []
    var currentDate = startDate
    while currentDate <= endDate {
      yearMonths.insert(dateFormatter.string(from: currentDate))
      // Move to next month
      if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) {
        currentDate = nextMonth
      } else {
        break
      }
    }
    
    // Load awards for each month
    var allAwards: [FirestoreDailyAward] = []
    for yearMonth in yearMonths {
      do {
        let monthAwards = try await loadDailyAwards(yearMonth: yearMonth)
        allAwards.append(contentsOf: monthAwards)
      } catch {
        // Month might not exist, continue silently
      }
    }
    
    // Filter to only include awards in the date range
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let startDateString = dateFormatter.string(from: startDate)
    let endDateString = dateFormatter.string(from: endDate)
    
    let filteredAwards = allAwards.filter { award in
      award.date >= startDateString && award.date <= endDateString
    }
    
    return filteredAwards
  }
  
  /// Load all daily awards for the current user
  @MainActor
  func loadAllDailyAwards() async throws -> [FirestoreDailyAward] {
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    // ✅ FIX: Check authentication but don't store userId (not used in this method)
    guard currentUserId != nil else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    // Get all month subcollections
    // Note: Firestore doesn't have a built-in way to list subcollections
    // So we'll need to track which months have data
    // For now, load the last 12 months
    var allAwards: [FirestoreDailyAward] = []
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    
    // Load last 12 months
    for monthOffset in 0..<12 {
      if let monthDate = Calendar.current.date(byAdding: .month, value: -monthOffset, to: Date()) {
        let yearMonth = dateFormatter.string(from: monthDate)
        do {
          let monthAwards = try await loadDailyAwards(yearMonth: yearMonth)
          allAwards.append(contentsOf: monthAwards)
        } catch {
          // Month might not exist, continue
          continue
        }
      }
    }
    
    return allAwards
  }
  
  /// Check if XP migration has been completed
  @MainActor
  func isXPMigrationComplete() async throws -> Bool {
    guard isConfigured else {
      return false
    }
    
    guard let userId = currentUserId else {
      return false
    }
    
    let snapshot = try await db.collection("users")
      .document(userId)
      .collection("meta")
      .document("xp_migration")
      .getDocument()
    
    if let data = snapshot.data(),
       let status = data["status"] as? String {
      return status == "complete"
    }
    
    return false
  }
  
  /// Mark XP migration as complete
  @MainActor
  func markXPMigrationComplete() async throws {
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    try await db.collection("users")
      .document(userId)
      .collection("meta")
      .document("xp_migration")
      .setData([
        "status": "complete",
        "completedAt": Date(),
        "version": "1.0"
      ])
    
    print("✅ FirestoreService: XP migration marked as complete")
  }
  
  /// Delete XP migration marker to allow re-running migration
  @MainActor
  func deleteXPMigrationMarker() async throws {
    guard isConfigured else {
      throw FirestoreServiceError.notConfigured
    }
    
    guard let userId = currentUserId else {
      throw FirestoreServiceError.notAuthenticated
    }
    
    try await db.collection("users")
      .document(userId)
      .collection("meta")
      .document("xp_migration")
      .delete()
    
    print("🗑️ FirestoreService: XP migration marker deleted")
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

