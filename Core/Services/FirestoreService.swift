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
    
    let fetchedHabits = snapshot.documents.compactMap { doc in
      do {
        let firestoreHabit = try doc.data(as: FirestoreHabit.self)
        return firestoreHabit.toHabit()
      } catch {
        print("❌ FirestoreService: Failed to decode habit \(doc.documentID): \(error)")
        return nil
      }
    }
    
    // ✅ Simple validation: only skip habits with invalid data that would cause crashes
    habits = fetchedHabits.filter { habit in
      // Skip breaking habits with invalid target/baseline (this is a real validation error)
      if habit.habitType == .breaking {
        let isValid = habit.target < habit.baseline && habit.baseline > 0
        if !isValid {
          print("⚠️ SKIPPING INVALID BREAKING HABIT: '\(habit.name)' (target=\(habit.target), baseline=\(habit.baseline))")
          return false
        }
      }
      return true
    }
    
    let skippedCount = fetchedHabits.count - habits.count
    if skippedCount > 0 {
      print("⚠️ FirestoreService: Skipped \(skippedCount) invalid habit(s)")
    }
    print("✅ FirestoreService: Fetched \(habits.count) valid habits")
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
          let fetchedHabits = snapshot.documents.compactMap { doc in
            do {
              let firestoreHabit = try doc.data(as: FirestoreHabit.self)
              return firestoreHabit.toHabit()
            } catch {
              print("❌ FirestoreService: Failed to decode habit \(doc.documentID): \(error)")
              return nil
            }
          }
          
          // ✅ Simple validation: only skip habits with invalid data that would cause crashes
          self.habits = fetchedHabits.filter { habit in
            // Skip breaking habits with invalid target/baseline (this is a real validation error)
            if habit.habitType == .breaking {
              let isValid = habit.target < habit.baseline && habit.baseline > 0
              if !isValid {
                print("⚠️ LISTENER: SKIPPING INVALID BREAKING HABIT: '\(habit.name)' (target=\(habit.target), baseline=\(habit.baseline))")
                return false
              }
            }
            return true
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
  
  // MARK: - XP & Progress Operations
  
  /// Save user's current progress (total XP, level, etc.)
  @MainActor
  func saveUserProgress(_ progress: FirestoreUserProgress) async throws {
    print("📊 FirestoreService: Saving user progress (totalXP: \(progress.totalXP), level: \(progress.level))")
    
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
          print("⚠️ FirestoreService: Skipping update - existing data is newer")
          return nil
        }
      }
      
      transaction.setData(progressData, forDocument: docRef)
      return nil
    })
    
    print("✅ FirestoreService: User progress saved")
  }
  
  /// Load user's current progress
  @MainActor
  func loadUserProgress() async throws -> FirestoreUserProgress? {
    print("📊 FirestoreService: Loading user progress")
    
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
      print("ℹ️ FirestoreService: No user progress found")
      return nil
    }
    
    let progress = FirestoreUserProgress.from(data: data)
    if let progress = progress {
      print("✅ FirestoreService: Loaded progress (totalXP: \(progress.totalXP), level: \(progress.level))")
    }
    
    return progress
  }
  
  /// Save a daily award
  @MainActor
  func saveDailyAward(_ award: FirestoreDailyAward) async throws {
    print("🏆 FirestoreService: Saving daily award for \(award.date) (XP: \(award.xpGranted))")
    
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
    
    print("✅ FirestoreService: Daily award saved at path: daily_awards/\(yearMonth)/\(day)")
  }
  
  /// Load daily awards for a specific month
  @MainActor
  func loadDailyAwards(yearMonth: String) async throws -> [FirestoreDailyAward] {
    print("📊 FirestoreService: Loading daily awards for \(yearMonth)")
    
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
    
    print("✅ FirestoreService: Loaded \(awards.count) daily awards for \(yearMonth)")
    return awards
  }
  
  /// Load daily awards for a date range
  @MainActor
  func loadDailyAwards(from startDate: Date, to endDate: Date) async throws -> [FirestoreDailyAward] {
    print("📊 FirestoreService: Loading daily awards from \(startDate) to \(endDate)")
    
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
        print("⚠️ FirestoreService: Failed to load awards for \(yearMonth): \(error)")
      }
    }
    
    // Filter to only include awards in the date range
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let startDateString = dateFormatter.string(from: startDate)
    let endDateString = dateFormatter.string(from: endDate)
    
    let filteredAwards = allAwards.filter { award in
      award.date >= startDateString && award.date <= endDateString
    }
    
    print("✅ FirestoreService: Loaded \(filteredAwards.count) daily awards in range")
    return filteredAwards
  }
  
  /// Load all daily awards for the current user
  @MainActor
  func loadAllDailyAwards() async throws -> [FirestoreDailyAward] {
    print("📊 FirestoreService: Loading all daily awards")
    
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
    
    print("✅ FirestoreService: Loaded \(allAwards.count) total daily awards")
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

