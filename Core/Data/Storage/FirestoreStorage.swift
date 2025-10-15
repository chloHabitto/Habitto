import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

// MARK: - FirestoreStorage

/// Firestore implementation of the habit storage protocol
/// Provides cloud-based persistence with offline support
@MainActor
final class FirestoreStorage: HabitStorageProtocol {
  // MARK: Lifecycle

  init() {
    logger.info("🔥 FirestoreStorage: Initializing Firestore storage")
    setupFirestore()
  }

  // MARK: Internal

  typealias DataType = Habit

  // MARK: - Generic Data Storage Methods

  func save(_ data: some Codable & Sendable, forKey key: String, immediate: Bool = false) async throws {
    logger.warning("Generic save called for key: \(key) - consider using specific methods")
    
    guard let userId = getCurrentUserId() else {
      throw FirestoreError.userNotAuthenticated
    }
    
    let documentId = "\(key)_\(userId)"
    let document = db.collection("generic_data").document(documentId)
    
    do {
      let encoded = try JSONEncoder().encode(data)
      let dataDict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] ?? [:]
      
      try await document.setData([
        "data": dataDict,
        "userId": userId,
        "key": key,
        "updatedAt": Timestamp(date: Date())
      ])
      
      logger.info("✅ Generic data saved for key: \(key)")
    } catch {
      logger.error("❌ Failed to save generic data for key \(key): \(error.localizedDescription)")
      throw error
    }
  }

  func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
    logger.warning("Generic load called for key: \(key) - consider using specific methods")
    
    guard let userId = getCurrentUserId() else {
      throw FirestoreError.userNotAuthenticated
    }
    
    let documentId = "\(key)_\(userId)"
    let document = db.collection("generic_data").document(documentId)
    
    do {
      let snapshot = try await document.getDocument()
      guard snapshot.exists,
            let data = snapshot.data(),
            let dataDict = data["data"] as? [String: Any] else {
        return nil
      }
      
      let jsonData = try JSONSerialization.data(withJSONObject: dataDict)
      let result = try JSONDecoder().decode(type, from: jsonData)
      
      logger.info("✅ Generic data loaded for key: \(key)")
      return result
    } catch {
      logger.error("❌ Failed to load generic data for key \(key): \(error.localizedDescription)")
      throw error
    }
  }

  func delete(forKey key: String) async throws {
    logger.warning("Generic delete called for key: \(key) - consider using specific methods")
    
    guard let userId = getCurrentUserId() else {
      throw FirestoreError.userNotAuthenticated
    }
    
    let documentId = "\(key)_\(userId)"
    let document = db.collection("generic_data").document(documentId)
    
    try await document.delete()
    logger.info("✅ Generic data deleted for key: \(key)")
  }

  func exists(forKey key: String) async throws -> Bool {
    guard let userId = getCurrentUserId() else {
      return false
    }
    
    let documentId = "\(key)_\(userId)"
    let document = db.collection("generic_data").document(documentId)
    
    let snapshot = try await document.getDocument()
    return snapshot.exists
  }

  func keys(withPrefix prefix: String) async throws -> [String] {
    guard let userId = getCurrentUserId() else {
      return []
    }
    
    let query = db.collection("generic_data")
      .whereField("userId", isEqualTo: userId)
      .whereField("key", isGreaterThanOrEqualTo: prefix)
      .whereField("key", isLessThan: prefix + "\u{f8ff}")
    
    let snapshot = try await query.getDocuments()
    return snapshot.documents.compactMap { doc in
      doc.data()["key"] as? String
    }
  }

  // MARK: - Habit-Specific Storage Methods

  func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
    guard let userId = getCurrentUserId() else {
      throw FirestoreError.userNotAuthenticated
    }
    
    logger.info("🔥 Saving \(habits.count) habits to Firestore")
    
    // Use batch write for atomicity
    let batch = db.batch()
    
    for habit in habits {
      let document = db.collection("habits").document(habit.id.uuidString)
      let habitData = habitToFirestoreData(habit, userId: userId)
      batch.setData(habitData, forDocument: document)
    }
    
    do {
      try await batch.commit()
      logger.info("✅ Successfully saved \(habits.count) habits to Firestore")
      
      // Update cache
      cachedHabits = habits
    } catch {
      logger.error("❌ Failed to save habits to Firestore: \(error.localizedDescription)")
      throw error
    }
  }

  func loadHabits() async throws -> [Habit] {
    guard let userId = getCurrentUserId() else {
      logger.warning("⚠️ User not authenticated, returning empty habits")
      return []
    }
    
    // Return cached result if available
    if let cached = cachedHabits {
      return cached
    }
    
    logger.info("🔥 Loading habits from Firestore for user: \(userId)")
    
    do {
      let query = db.collection("habits")
        .whereField("userId", isEqualTo: userId)
        .order(by: "createdAt", descending: false)
      
      let snapshot = try await query.getDocuments()
      let habits = snapshot.documents.compactMap { doc -> Habit? in
        firestoreDataToHabit(doc.data())
      }
      
      logger.info("✅ Loaded \(habits.count) habits from Firestore")
      
      // Update cache
      cachedHabits = habits
      return habits
    } catch {
      logger.error("❌ Failed to load habits from Firestore: \(error.localizedDescription)")
      throw error
    }
  }

  func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
    guard let userId = getCurrentUserId() else {
      throw FirestoreError.userNotAuthenticated
    }
    
    logger.info("🔥 Saving habit '\(habit.name)' to Firestore")
    
    let document = db.collection("habits").document(habit.id.uuidString)
    let habitData = habitToFirestoreData(habit, userId: userId)
    
    do {
      try await document.setData(habitData)
      logger.info("✅ Successfully saved habit '\(habit.name)' to Firestore")
      
      // Update cache
      if var cached = cachedHabits {
        if let index = cached.firstIndex(where: { $0.id == habit.id }) {
          cached[index] = habit
        } else {
          cached.append(habit)
        }
        cachedHabits = cached
      }
    } catch {
      logger.error("❌ Failed to save habit '\(habit.name)' to Firestore: \(error.localizedDescription)")
      throw error
    }
  }

  func loadHabit(id: UUID) async throws -> Habit? {
    logger.info("🔥 Loading habit with ID: \(id)")
    
    let document = db.collection("habits").document(id.uuidString)
    
    do {
      let snapshot = try await document.getDocument()
      guard snapshot.exists else {
        logger.info("ℹ️ Habit with ID \(id) not found in Firestore")
        return nil
      }
      
      let habit = firestoreDataToHabit(snapshot.data() ?? [:])
      logger.info("✅ Loaded habit '\(habit?.name ?? "Unknown")' from Firestore")
      return habit
    } catch {
      logger.error("❌ Failed to load habit with ID \(id) from Firestore: \(error.localizedDescription)")
      throw error
    }
  }

  func deleteHabit(id: UUID) async throws {
    logger.info("🔥 Deleting habit with ID: \(id)")
    
    let document = db.collection("habits").document(id.uuidString)
    
    do {
      try await document.delete()
      logger.info("✅ Successfully deleted habit with ID: \(id)")
      
      // Update cache
      if var cached = cachedHabits {
        cached.removeAll { $0.id == id }
        cachedHabits = cached
      }
    } catch {
      logger.error("❌ Failed to delete habit with ID \(id) from Firestore: \(error.localizedDescription)")
      throw error
    }
  }

  func clearAllHabits() async throws {
    guard let userId = getCurrentUserId() else {
      throw FirestoreError.userNotAuthenticated
    }
    
    logger.info("🔥 Clearing all habits for user: \(userId)")
    
    do {
      // Get all habits for the user
      let query = db.collection("habits").whereField("userId", isEqualTo: userId)
      let snapshot = try await query.getDocuments()
      
      // Delete in batches
      let batch = db.batch()
      for document in snapshot.documents {
        batch.deleteDocument(document.reference)
      }
      
      try await batch.commit()
      logger.info("✅ Successfully cleared all habits for user")
      
      // Update cache
      cachedHabits = []
    } catch {
      logger.error("❌ Failed to clear habits from Firestore: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Cache Management

  func clearCache() {
    cachedHabits = nil
    logger.info("🧹 Cleared Firestore cache")
  }

  func getCacheStatus() -> (isCached: Bool, count: Int) {
    (cachedHabits != nil, cachedHabits?.count ?? 0)
  }

  // MARK: Private

  private let db = Firestore.firestore()
  private var cachedHabits: [Habit]?
  private let logger = Logger(subsystem: "com.habitto.app", category: "FirestoreStorage")

  /// Setup Firestore configuration
  private func setupFirestore() {
    let settings = FirestoreSettings()
    settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
    db.settings = settings
    
    logger.info("✅ Firestore configured with offline persistence")
  }

  /// Get current authenticated user ID
  private func getCurrentUserId() -> String? {
    Auth.auth().currentUser?.uid
  }

  /// Convert Habit to Firestore data
  private func habitToFirestoreData(_ habit: Habit, userId: String) -> [String: Any] {
    do {
      // Convert habit to JSON data
      let jsonData = try JSONEncoder().encode(habit)
      let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
      
      // Add Firestore-specific fields
      var firestoreData = jsonObject
      firestoreData["userId"] = userId
      firestoreData["updatedAt"] = Timestamp(date: Date())
      
      return firestoreData
    } catch {
      logger.error("❌ Failed to convert habit to Firestore data: \(error.localizedDescription)")
      return [
        "id": habit.id.uuidString,
        "name": habit.name,
        "description": habit.description,
        "userId": userId,
        "updatedAt": Timestamp(date: Date())
      ]
    }
  }

  /// Convert Firestore data to Habit
  private func firestoreDataToHabit(_ data: [String: Any]) -> Habit? {
    do {
      // Remove Firestore-specific fields before decoding
      var habitData = data
      habitData.removeValue(forKey: "userId")
      habitData.removeValue(forKey: "updatedAt")
      
      // Convert to JSON data
      let jsonData = try JSONSerialization.data(withJSONObject: habitData)
      let habit = try JSONDecoder().decode(Habit.self, from: jsonData)
      
      return habit
    } catch {
      logger.error("❌ Failed to convert Firestore data to habit: \(error.localizedDescription)")
      return nil
    }
  }
}


