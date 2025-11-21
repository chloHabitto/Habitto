import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import OSLog

// MARK: - FirebaseBackupService

/// Service for non-blocking cloud backup to Firestore
/// Handles backup of habits, completions, and daily awards
/// All operations are non-blocking and fail silently to not interrupt user experience
@MainActor
class FirebaseBackupService {
  // MARK: Lifecycle

  private init() {
    logger.info("🔥 FirebaseBackupService: Initialized")
  }

  // MARK: Internal

  static let shared = FirebaseBackupService()

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "FirebaseBackupService")
  private var db: Firestore { Firestore.firestore() }

  // MARK: - Backup Methods

  /// Backup a habit to Firestore (non-blocking)
  /// Collection: users/{userId}/habits/{habitId}
  func backupHabit(_ habit: Habit) {
    Task.detached { [weak self] in
      await self?.performHabitBackup(habit)
    }
  }

  /// Backup a completion record to Firestore (non-blocking)
  /// Collection: users/{userId}/completions/{yearMonth}/{recordId}
  func backupCompletionRecord(
    habitId: UUID,
    date: Date,
    dateKey: String,
    isCompleted: Bool,
    progress: Int)
  {
    Task.detached { [weak self] in
      await self?.performCompletionBackup(
        habitId: habitId,
        date: date,
        dateKey: dateKey,
        isCompleted: isCompleted,
        progress: progress)
    }
  }

  /// Backup a daily award to Firestore (non-blocking)
  /// Collection: users/{userId}/daily_awards/{dateKey}
  func backupDailyAward(
    dateKey: String,
    xpGranted: Int,
    allHabitsCompleted: Bool)
  {
    Task.detached { [weak self] in
      await self?.performDailyAwardBackup(
        dateKey: dateKey,
        xpGranted: xpGranted,
        allHabitsCompleted: allHabitsCompleted)
    }
  }

  /// Delete a habit from Firestore backup (non-blocking)
  func deleteHabitBackup(habitId: UUID) {
    Task.detached { [weak self] in
      await self?.performHabitDeletion(habitId: habitId)
    }
  }

  // MARK: - Private Implementation

  private func performHabitBackup(_ habit: Habit) async {
    guard let userId = await getCurrentUserId() else {
      logger.debug("⏭️ FirebaseBackupService: Skipping habit backup - no authenticated user")
      return
    }

    guard FirebaseApp.app() != nil else {
      logger.debug("⏭️ FirebaseBackupService: Skipping habit backup - Firebase not configured")
      return
    }

    do {
      let firestoreHabit = FirestoreHabit(from: habit)
      let habitData = firestoreHabit.toFirestoreData()
      
      // Add syncedAt timestamp
      var dataWithTimestamp = habitData
      dataWithTimestamp["syncedAt"] = Timestamp(date: Date())

      let docRef = db.collection("users")
        .document(userId)
        .collection("habits")
        .document(habit.id.uuidString)

      try await docRef.setData(dataWithTimestamp, merge: true)
      
      print("☁️ [CLOUD_BACKUP] Habit backed up successfully")
      print("   Habit: '\(habit.name)'")
      print("   Habit ID: \(habit.id.uuidString.prefix(8))...")
      print("   User ID: \(userId.prefix(8))...")
      logger.info("✅ FirebaseBackupService: Backed up habit '\(habit.name)' to Firestore")
    } catch {
      // ✅ IMPROVED: Better error handling for permission errors
      let errorDesc = error.localizedDescription.lowercased()
      if errorDesc.contains("permission") || errorDesc.contains("insufficient") {
        print("⚠️ [CLOUD_BACKUP] Permission denied - Firestore security rules need configuration")
        print("   Habit: '\(habit.name)'")
        print("   💡 See FIREBASE_SECURITY_RULES.md for setup instructions")
        logger.warning("⚠️ FirebaseBackupService: Permission denied for habit '\(habit.name)' - check Firestore security rules")
      } else {
        print("⚠️ [CLOUD_BACKUP] Habit backup failed: \(error.localizedDescription)")
        print("   Habit: '\(habit.name)'")
        logger.warning("⚠️ FirebaseBackupService: Failed to backup habit '\(habit.name)': \(error.localizedDescription)")
      }
      // Fail silently - don't interrupt user experience
    }
  }

  private func performCompletionBackup(
    habitId: UUID,
    date: Date,
    dateKey: String,
    isCompleted: Bool,
    progress: Int) async
  {
    guard let userId = await getCurrentUserId() else {
      return
    }

    guard FirebaseApp.app() != nil else {
      return
    }

    do {
      // Organize by year-month for efficient queries
      let calendar = Calendar.current
      let year = calendar.component(.year, from: date)
      let month = calendar.component(.month, from: date)
      let yearMonth = String(format: "%04d-%02d", year, month)
      
      // Use dateKey as document ID for uniqueness
      let recordId = "\(habitId.uuidString)_\(dateKey)"

      let completionData: [String: Any] = [
        "habitId": habitId.uuidString,
        "date": Timestamp(date: date),
        "dateKey": dateKey,
        "isCompleted": isCompleted,
        "progress": progress,
        "syncedAt": Timestamp(date: Date())
      ]

      let docRef = db.collection("users")
        .document(userId)
        .collection("completions")
        .document(yearMonth)
        .collection("records")
        .document(recordId)

      try await docRef.setData(completionData, merge: true)
      
      print("☁️ [CLOUD_BACKUP] Completion record backed up successfully")
      print("   Habit ID: \(habitId.uuidString.prefix(8))...")
      print("   Date: \(dateKey)")
      print("   Progress: \(progress)")
      print("   Completed: \(isCompleted)")
      logger.debug("✅ FirebaseBackupService: Backed up completion record for habit \(habitId.uuidString.prefix(8))... on \(dateKey)")
    } catch {
      // ✅ IMPROVED: Better error handling for permission errors
      let errorDesc = error.localizedDescription.lowercased()
      if errorDesc.contains("permission") || errorDesc.contains("insufficient") {
        logger.debug("⚠️ FirebaseBackupService: Permission denied for completion record - check Firestore security rules")
      } else {
        print("⚠️ [CLOUD_BACKUP] Completion backup failed: \(error.localizedDescription)")
        print("   Habit ID: \(habitId.uuidString.prefix(8))..., Date: \(dateKey)")
        logger.warning("⚠️ FirebaseBackupService: Failed to backup completion record: \(error.localizedDescription)")
      }
    }
  }

  private func performDailyAwardBackup(
    dateKey: String,
    xpGranted: Int,
    allHabitsCompleted: Bool) async
  {
    guard let userId = await getCurrentUserId() else {
      return
    }

    guard FirebaseApp.app() != nil else {
      return
    }

    do {
      let awardData: [String: Any] = [
        "dateKey": dateKey,
        "xpGranted": xpGranted,
        "allHabitsCompleted": allHabitsCompleted,
        "grantedAt": Timestamp(date: Date()),
        "syncedAt": Timestamp(date: Date())
      ]

      let docRef = db.collection("users")
        .document(userId)
        .collection("daily_awards")
        .document(dateKey)

      try await docRef.setData(awardData, merge: true)
      
      print("☁️ [CLOUD_BACKUP] Daily award backed up successfully")
      print("   Date: \(dateKey)")
      print("   XP Granted: \(xpGranted)")
      print("   All Habits Completed: \(allHabitsCompleted)")
      logger.debug("✅ FirebaseBackupService: Backed up daily award for \(dateKey)")
    } catch {
      // ✅ IMPROVED: Better error handling for permission errors
      let errorDesc = error.localizedDescription.lowercased()
      if errorDesc.contains("permission") || errorDesc.contains("insufficient") {
        logger.debug("⚠️ FirebaseBackupService: Permission denied for daily award - check Firestore security rules")
      } else {
        print("⚠️ [CLOUD_BACKUP] Daily award backup failed: \(error.localizedDescription)")
        print("   Date: \(dateKey)")
        logger.warning("⚠️ FirebaseBackupService: Failed to backup daily award: \(error.localizedDescription)")
      }
    }
  }

  private func performHabitDeletion(habitId: UUID) async {
    guard let userId = await getCurrentUserId() else {
      return
    }

    guard FirebaseApp.app() != nil else {
      return
    }

    do {
      let docRef = db.collection("users")
        .document(userId)
        .collection("habits")
        .document(habitId.uuidString)

      try await docRef.delete()
      
      print("☁️ [CLOUD_BACKUP] Habit deleted from Firestore")
      print("   Habit ID: \(habitId.uuidString.prefix(8))...")
      logger.info("✅ FirebaseBackupService: Deleted habit backup \(habitId.uuidString.prefix(8))... from Firestore")
    } catch {
      print("⚠️ [CLOUD_BACKUP] Habit deletion failed: \(error.localizedDescription)")
      print("   Habit ID: \(habitId.uuidString.prefix(8))...")
      logger.warning("⚠️ FirebaseBackupService: Failed to delete habit backup: \(error.localizedDescription)")
    }
  }

  // MARK: - Helper Methods

  private func getCurrentUserId() async -> String? {
    await MainActor.run {
      // Check Firebase Auth first
      if let firebaseUser = Auth.auth().currentUser {
        return firebaseUser.uid
      }
      
      // Fallback to AuthenticationManager
      if let user = AuthenticationManager.shared.currentUser {
        return user.uid
      }
      
      return nil
    }
  }
}

