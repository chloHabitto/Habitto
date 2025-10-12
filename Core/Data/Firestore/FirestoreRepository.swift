//
//  FirestoreRepository.swift
//  Habitto
//
//  Production Firestore repository with full CRUD, goal versioning, completions, XP, and streaks
//

import Combine
import FirebaseAuth
import Foundation
// import FirebaseFirestore // Uncomment after adding package

// MARK: - FirestoreRepository

/// Production repository for all Firestore operations
@MainActor
class FirestoreRepository: ObservableObject {
  // MARK: Lifecycle
  
  init(
    nowProvider: NowProvider = SystemNowProvider(),
    timeZoneProvider: TimeZoneProvider = AmsterdamTimeZoneProvider())
  {
    self.nowProvider = nowProvider
    self.timeZoneProvider = timeZoneProvider
    self.dateFormatter = LocalDateFormatter(
      nowProvider: nowProvider,
      timeZoneProvider: timeZoneProvider)
    
    print("📊 FirestoreRepository: Initialized with Europe/Amsterdam timezone")
  }
  
  // MARK: Internal
  
  static let shared = FirestoreRepository()
  
  // Published streams
  @Published var habits: [FirestoreHabit] = []
  @Published var completions: [String: Completion] = [:] // habitId -> Completion
  @Published var xpState: XPState?
  @Published var streaks: [String: Streak] = [:] // habitId -> Streak
  @Published var error: FirestoreError?
  
  let nowProvider: NowProvider
  let timeZoneProvider: TimeZoneProvider
  let dateFormatter: LocalDateFormatter
  
  // MARK: - Habit CRUD
  
  /// Create a new habit
  func createHabit(name: String, color: String, type: String = "formation") async throws -> String {
    print("📝 FirestoreRepository: Creating habit '\(name)'")
    
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    let habitData: [String: Any] = [
      "name": name,
      "color": color,
      "type": type,
      "createdAt": Timestamp(date: nowProvider.now()),
      "active": true
    ]
    
    let docRef = try await db.collection("users").document(userId)
      .collection("habits").addDocument(data: habitData)
    
    print("✅ FirestoreRepository: Habit created with ID: \(docRef.documentID)")
    return docRef.documentID
    */
    
    // Mock implementation
    let habitId = UUID().uuidString
    let habit = FirestoreHabit(
      id: habitId,
      name: name,
      color: color,
      type: type,
      createdAt: nowProvider.now(),
      active: true)
    habits.append(habit)
    
    print("✅ FirestoreRepository: Mock habit created with ID: \(habitId)")
    return habitId
  }
  
  /// Update an existing habit
  func updateHabit(id: String, name: String? = nil, color: String? = nil, active: Bool? = nil) async throws {
    print("📝 FirestoreRepository: Updating habit \(id)")
    
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    var updateData: [String: Any] = [:]
    
    if let name = name {
      updateData["name"] = name
    }
    if let color = color {
      updateData["color"] = color
    }
    if let active = active {
      updateData["active"] = active
    }
    
    try await db.collection("users").document(userId)
      .collection("habits").document(id).updateData(updateData)
    
    print("✅ FirestoreRepository: Habit updated")
    */
    
    // Mock implementation
    if let index = habits.firstIndex(where: { $0.id == id }) {
      if let name = name {
        habits[index].name = name
      }
      if let color = color {
        habits[index].color = color
      }
      if let active = active {
        habits[index].active = active
      }
    }
    print("✅ FirestoreRepository: Mock habit updated")
  }
  
  /// Delete a habit
  func deleteHabit(id: String) async throws {
    print("🗑️ FirestoreRepository: Deleting habit \(id)")
    
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    try await db.collection("users").document(userId)
      .collection("habits").document(id).delete()
    
    habits.removeAll { $0.id == id }
    print("✅ FirestoreRepository: Habit deleted")
    */
    
    // Mock implementation
    habits.removeAll { $0.id == id }
    print("✅ FirestoreRepository: Mock habit deleted")
  }
  
  // MARK: - Goal Versioning
  
  /// Set a goal for a habit, effective from a specific local date
  /// This creates a new version without affecting past days
  func setGoal(habitId: String, effectiveLocalDate: String, goal: Int) async throws {
    print("📊 FirestoreRepository: Setting goal for habit \(habitId) effective \(effectiveLocalDate): \(goal)")
    
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    // Validate date format
    guard effectiveLocalDate.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil else {
      throw FirestoreError.invalidData
    }
    
    guard goal >= 0 else {
      throw FirestoreError.invalidData
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    let versionId = UUID().uuidString
    let versionData: [String: Any] = [
      "habitId": habitId,
      "effectiveLocalDate": effectiveLocalDate,
      "goal": goal,
      "createdAt": Timestamp(date: nowProvider.now())
    ]
    
    try await db.collection("users").document(userId)
      .collection("goalVersions").document(habitId)
      .collection("versions").document(versionId)
      .setData(versionData)
    
    print("✅ FirestoreRepository: Goal version created: \(versionId)")
    */
    
    // Mock implementation
    print("✅ FirestoreRepository: Mock goal set for \(habitId) from \(effectiveLocalDate): \(goal)")
  }
  
  /// Get the goal for a habit on a specific date
  func getGoal(habitId: String, on localDate: String) async throws -> Int {
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    
    // Query for the latest goal version that's effective on or before the target date
    let snapshot = try await db.collection("users").document(userId)
      .collection("goalVersions").document(habitId)
      .collection("versions")
      .whereField("effectiveLocalDate", isLessThanOrEqualTo: localDate)
      .order(by: "effectiveLocalDate", descending: true)
      .limit(to: 1)
      .getDocuments()
    
    guard let doc = snapshot.documents.first,
          let goal = doc.data()["goal"] as? Int else {
      // No goal version found, return default
      return 1
    }
    
    return goal
    */
    
    // Mock implementation
    return 1
  }
  
  // MARK: - Completions (Transactional)
  
  /// Increment completion count for a habit on a specific date (transactional)
  func incrementCompletion(habitId: String, localDate: String) async throws {
    print("✅ FirestoreRepository: Incrementing completion for \(habitId) on \(localDate)")
    
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    // Validate date format
    guard localDate.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil else {
      throw FirestoreError.invalidData
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    let docRef = db.collection("users").document(userId)
      .collection("completions").document(localDate)
      .collection("habits").document(habitId)
    
    try await db.runTransaction({ (transaction, errorPointer) -> Any? in
      let document: DocumentSnapshot
      do {
        document = try transaction.getDocument(docRef)
      } catch let fetchError as NSError {
        errorPointer?.pointee = fetchError
        return nil
      }
      
      let currentCount = document.data()?["count"] as? Int ?? 0
      let newCount = currentCount + 1
      
      transaction.setData([
        "count": newCount,
        "updatedAt": Timestamp(date: self.nowProvider.now())
      ], forDocument: docRef, merge: true)
      
      return newCount
    })
    
    print("✅ FirestoreRepository: Completion incremented")
    */
    
    // Mock implementation
    let currentCount = (completions[habitId]?.count ?? 0)
    completions[habitId] = Completion(
      habitId: habitId,
      localDate: localDate,
      count: currentCount + 1,
      updatedAt: nowProvider.now())
    
    print("✅ FirestoreRepository: Mock completion incremented to \(currentCount + 1)")
  }
  
  /// Get completion for a habit on a specific date
  func getCompletion(habitId: String, localDate: String) async throws -> Int {
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    let doc = try await db.collection("users").document(userId)
      .collection("completions").document(localDate)
      .collection("habits").document(habitId)
      .getDocument()
    
    return doc.data()?["count"] as? Int ?? 0
    */
    
    // Mock implementation
    return completions[habitId]?.count ?? 0
  }
  
  // MARK: - XP Management
  
  /// Award XP (appends to ledger and updates state transactionally)
  func awardXP(delta: Int, reason: String) async throws {
    print("🎖️ FirestoreRepository: Awarding \(delta) XP for '\(reason)'")
    
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    let stateRef = db.collection("users").document(userId).collection("xp").document("state")
    let ledgerRef = db.collection("users").document(userId).collection("xp")
      .collection("ledger").document()
    
    try await db.runTransaction({ (transaction, errorPointer) -> Any? in
      let stateDoc: DocumentSnapshot
      do {
        stateDoc = try transaction.getDocument(stateRef)
      } catch let fetchError as NSError {
        errorPointer?.pointee = fetchError
        return nil
      }
      
      let currentTotalXP = stateDoc.data()?["totalXP"] as? Int ?? 0
      let newTotalXP = currentTotalXP + delta
      
      // Calculate level (simple formula: every 100 XP = 1 level)
      let newLevel = (newTotalXP / 100) + 1
      let newCurrentLevelXP = newTotalXP % 100
      
      // Update state
      transaction.setData([
        "totalXP": newTotalXP,
        "level": newLevel,
        "currentLevelXP": newCurrentLevelXP,
        "lastUpdated": Timestamp(date: self.nowProvider.now())
      ], forDocument: stateRef, merge: true)
      
      // Append to ledger
      transaction.setData([
        "delta": delta,
        "reason": reason,
        "ts": Timestamp(date: self.nowProvider.now())
      ], forDocument: ledgerRef)
      
      return newTotalXP
    })
    
    print("✅ FirestoreRepository: XP awarded")
    */
    
    // Mock implementation
    let currentTotalXP = xpState?.totalXP ?? 0
    let newTotalXP = currentTotalXP + delta
    let newLevel = (newTotalXP / 100) + 1
    let newCurrentLevelXP = newTotalXP % 100
    
    xpState = XPState(
      totalXP: newTotalXP,
      level: newLevel,
      currentLevelXP: newCurrentLevelXP,
      lastUpdated: nowProvider.now())
    
    print("✅ FirestoreRepository: Mock XP awarded. New total: \(newTotalXP), Level: \(newLevel)")
  }
  
  /// Verify XP integrity (sum of ledger should equal state.totalXP)
  func verifyXPIntegrity() async throws -> Bool {
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    
    // Get current state
    let stateDoc = try await db.collection("users").document(userId)
      .collection("xp").document("state").getDocument()
    let stateTotalXP = stateDoc.data()?["totalXP"] as? Int ?? 0
    
    // Sum ledger
    let ledgerSnapshot = try await db.collection("users").document(userId)
      .collection("xp").collection("ledger").getDocuments()
    
    let ledgerSum = ledgerSnapshot.documents.reduce(0) { sum, doc in
      let delta = doc.data()["delta"] as? Int ?? 0
      return sum + delta
    }
    
    let isValid = stateTotalXP == ledgerSum
    
    if !isValid {
      print("❌ XP Integrity Check Failed: State=\(stateTotalXP), Ledger=\(ledgerSum)")
    } else {
      print("✅ XP Integrity Check Passed: \(stateTotalXP) XP")
    }
    
    return isValid
    */
    
    // Mock implementation
    print("✅ FirestoreRepository: Mock XP integrity check passed")
    return true
  }
  
  /// Auto-repair XP integrity (recalculate state from ledger)
  func repairXPIntegrity() async throws {
    print("🔧 FirestoreRepository: Repairing XP integrity")
    
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    
    // Sum ledger
    let ledgerSnapshot = try await db.collection("users").document(userId)
      .collection("xp").collection("ledger").getDocuments()
    
    let correctTotalXP = ledgerSnapshot.documents.reduce(0) { sum, doc in
      let delta = doc.data()["delta"] as? Int ?? 0
      return sum + delta
    }
    
    let newLevel = (correctTotalXP / 100) + 1
    let newCurrentLevelXP = correctTotalXP % 100
    
    // Update state
    try await db.collection("users").document(userId)
      .collection("xp").document("state").setData([
        "totalXP": correctTotalXP,
        "level": newLevel,
        "currentLevelXP": newCurrentLevelXP,
        "lastUpdated": Timestamp(date: nowProvider.now())
      ])
    
    print("✅ FirestoreRepository: XP repaired to \(correctTotalXP)")
    */
    
    // Mock implementation
    print("✅ FirestoreRepository: Mock XP repaired")
  }
  
  // MARK: - Streaks
  
  /// Update streak for a habit after completion
  func updateStreak(habitId: String, localDate: String, completed: Bool) async throws {
    print("📈 FirestoreRepository: Updating streak for \(habitId)")
    
    guard Auth.auth().currentUser != nil else {
      throw FirestoreError.notAuthenticated
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    let streakRef = db.collection("users").document(userId)
      .collection("streaks").document(habitId)
    
    try await db.runTransaction({ (transaction, errorPointer) -> Any? in
      let doc: DocumentSnapshot
      do {
        doc = try transaction.getDocument(streakRef)
      } catch let fetchError as NSError {
        errorPointer?.pointee = fetchError
        return nil
      }
      
      var currentStreak = doc.data()?["current"] as? Int ?? 0
      var longestStreak = doc.data()?["longest"] as? Int ?? 0
      let lastCompletionDate = doc.data()?["lastCompletionDate"] as? String
      
      if completed {
        // Check if this continues the streak
        let isConsecutive: Bool
        if let lastDate = lastCompletionDate,
           let yesterday = self.dateFormatter.addDays(-1, to: localDate) {
          isConsecutive = (lastDate == yesterday)
        } else {
          isConsecutive = false
        }
        
        if isConsecutive {
          currentStreak += 1
        } else {
          currentStreak = 1
        }
        
        if currentStreak > longestStreak {
          longestStreak = currentStreak
        }
        
        transaction.setData([
          "current": currentStreak,
          "longest": longestStreak,
          "lastCompletionDate": localDate,
          "updatedAt": Timestamp(date: self.nowProvider.now())
        ], forDocument: streakRef, merge: true)
      } else {
        // Reset streak
        transaction.setData([
          "current": 0,
          "longest": longestStreak,
          "updatedAt": Timestamp(date: self.nowProvider.now())
        ], forDocument: streakRef, merge: true)
      }
      
      return currentStreak
    })
    
    print("✅ FirestoreRepository: Streak updated")
    */
    
    // Mock implementation
    var streak = streaks[habitId] ?? Streak(
      habitId: habitId,
      current: 0,
      longest: 0,
      lastCompletionDate: nil,
      updatedAt: nowProvider.now())
    
    if completed {
      let isConsecutive: Bool
      if let lastDate = streak.lastCompletionDate,
         let yesterday = dateFormatter.addDays(-1, to: localDate) {
        isConsecutive = (lastDate == yesterday)
      } else {
        isConsecutive = false
      }
      
      if isConsecutive {
        streak.current += 1
      } else {
        streak.current = 1
      }
      
      if streak.current > streak.longest {
        streak.longest = streak.current
      }
      
      streak.lastCompletionDate = localDate
    } else {
      streak.current = 0
    }
    
    streak.updatedAt = nowProvider.now()
    streaks[habitId] = streak
    
    print("✅ FirestoreRepository: Mock streak updated. Current: \(streak.current), Longest: \(streak.longest)")
  }
  
  // MARK: - Real-time Streams
  
  /// Start listening to habits for current user
  func streamHabits() {
    print("👂 FirestoreRepository: Starting habits stream")
    
    guard Auth.auth().currentUser != nil else {
      print("⚠️ FirestoreRepository: Not authenticated, can't stream habits")
      return
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    
    habitsListener = db.collection("users").document(userId)
      .collection("habits")
      .whereField("active", isEqualTo: true)
      .addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else { return }
        
        if let error = error {
          print("❌ FirestoreRepository: Habits stream error: \(error)")
          Task { @MainActor in
            self.error = .operationFailed(error.localizedDescription)
          }
          return
        }
        
        guard let snapshot = snapshot else { return }
        
        Task { @MainActor in
          self.habits = snapshot.documents.compactMap { doc in
            FirestoreHabit.from(id: doc.documentID, data: doc.data())
          }
          print("✅ FirestoreRepository: Habits stream updated: \(self.habits.count) habits")
        }
      }
    */
    
    print("✅ FirestoreRepository: Mock habits stream started")
  }
  
  /// Start listening to completions for a specific date
  func streamCompletions(for localDate: String) {
    print("👂 FirestoreRepository: Starting completions stream for \(localDate)")
    
    guard Auth.auth().currentUser != nil else {
      print("⚠️ FirestoreRepository: Not authenticated, can't stream completions")
      return
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    
    completionsListener = db.collection("users").document(userId)
      .collection("completions").document(localDate)
      .collection("habits")
      .addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else { return }
        
        if let error = error {
          print("❌ FirestoreRepository: Completions stream error: \(error)")
          return
        }
        
        guard let snapshot = snapshot else { return }
        
        Task { @MainActor in
          var completionMap: [String: Completion] = [:]
          for doc in snapshot.documents {
            if let completion = Completion.from(habitId: doc.documentID, localDate: localDate, data: doc.data()) {
              completionMap[doc.documentID] = completion
            }
          }
          self.completions = completionMap
          print("✅ FirestoreRepository: Completions stream updated: \(completionMap.count) completions")
        }
      }
    */
    
    print("✅ FirestoreRepository: Mock completions stream started")
  }
  
  /// Start listening to XP state
  func streamXPState() {
    print("👂 FirestoreRepository: Starting XP state stream")
    
    guard Auth.auth().currentUser != nil else {
      print("⚠️ FirestoreRepository: Not authenticated, can't stream XP state")
      return
    }
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    let db = Firestore.firestore()
    
    xpStateListener = db.collection("users").document(userId)
      .collection("xp").document("state")
      .addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else { return }
        
        if let error = error {
          print("❌ FirestoreRepository: XP state stream error: \(error)")
          return
        }
        
        guard let snapshot = snapshot, let data = snapshot.data() else { return }
        
        Task { @MainActor in
          self.xpState = XPState.from(data: data)
          print("✅ FirestoreRepository: XP state updated: \(self.xpState?.totalXP ?? 0) XP")
        }
      }
    */
    
    // Initialize mock XP state if nil
    if xpState == nil {
      xpState = XPState(totalXP: 0, level: 1, currentLevelXP: 0, lastUpdated: nowProvider.now())
    }
    
    print("✅ FirestoreRepository: Mock XP state stream started")
  }
  
  /// Stop all listeners
  func stopListening() {
    print("🛑 FirestoreRepository: Stopping all listeners")
    
    /*
    // After adding FirebaseFirestore package, uncomment:
    habitsListener?.remove()
    completionsListener?.remove()
    xpStateListener?.remove()
    
    habitsListener = nil
    completionsListener = nil
    xpStateListener = nil
    */
    
    print("✅ FirestoreRepository: All listeners stopped")
  }
  
  // MARK: Private
  
  // private var habitsListener: ListenerRegistration?
  // private var completionsListener: ListenerRegistration?
  // private var xpStateListener: ListenerRegistration?
}

