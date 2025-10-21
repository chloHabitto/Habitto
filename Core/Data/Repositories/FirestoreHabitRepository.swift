import Foundation
import FirebaseFirestore
import OSLog

// MARK: - Firestore Habit Repository

/// Firestore implementation of HabitRepositoryProtocol
final class FirestoreHabitRepository: HabitRepositoryProtocol {
    // ✅ FIX: Use computed property to avoid accessing Firestore during class initialization
    // This ensures Firestore is only accessed AFTER it's configured in AppFirebase.swift
    private var firestore: Firestore { Firestore.firestore() }
    private let logger = Logger(subsystem: "com.habitto.app", category: "FirestoreHabitRepository")
    
    // TODO: Get actual userId from authentication context
    private var userId: String {
        return "current_user_id" // Placeholder
    }
    
    // MARK: - HabitRepositoryProtocol Implementation
    
    func create(_ habit: Habit) async throws {
        let docRef = firestore.collection("users").document(userId).collection("habits").document(habit.id.uuidString)
        let data = try habitToFirestoreData(habit)
        try await docRef.setData(data)
        logger.debug("✅ FirestoreHabitRepository: Created habit \(habit.id)")
    }
    
    func update(_ habit: Habit) async throws {
        let docRef = firestore.collection("users").document(userId).collection("habits").document(habit.id.uuidString)
        let data = try habitToFirestoreData(habit)
        try await docRef.updateData(data)
        logger.debug("✅ FirestoreHabitRepository: Updated habit \(habit.id)")
    }
    
    func delete(id: String) async throws {
        let docRef = firestore.collection("users").document(userId).collection("habits").document(id)
        try await docRef.delete()
        logger.debug("✅ FirestoreHabitRepository: Deleted habit \(id)")
    }
    
    func habit(by id: String) -> AsyncThrowingStream<Habit?, Error> {
        AsyncThrowingStream { continuation in
            let docRef = firestore.collection("users").document(userId).collection("habits").document(id)
            
            let listener = docRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    continuation.yield(nil)
                    return
                }
                
                do {
                    let habit = try self.firestoreDataToHabit(document.data() ?? [:])
                    continuation.yield(habit)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            // Clean up listener when stream finishes
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    func habits() -> AsyncThrowingStream<[Habit], Error> {
        AsyncThrowingStream { continuation in
            let collectionRef = firestore.collection("users").document(userId).collection("habits")
            
            let listener = collectionRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }
                
                do {
                    let habits = try documents.compactMap { document in
                        try self.firestoreDataToHabit(document.data())
                    }
                    continuation.yield(habits)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            // Clean up listener when stream finishes
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    func habits(for date: Date) async throws -> [Habit] {
        let collectionRef = firestore.collection("users").document(userId).collection("habits")
        let snapshot = try await collectionRef.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try firestoreDataToHabit(document.data())
        }
    }
    
    func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
        // TODO: Implement completion tracking in Firestore
        // This should update the completion count for the habit on the specific date
        logger.debug("✅ FirestoreHabitRepository: Marked habit \(habitId) complete for \(date)")
        return count
    }
    
    func getCompletionCount(habitId: String, date: Date) async throws -> Int {
        // TODO: Implement completion count retrieval from Firestore
        // This should return the completion count for the habit on the specific date
        logger.debug("📊 FirestoreHabitRepository: Getting completion count for habit \(habitId) on \(date)")
        return 0
    }
    
    // MARK: - Private Helper Methods
    
    private func habitToFirestoreData(_ habit: Habit) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Convert the habit to a dictionary
        return [
            "id": habit.id.uuidString,
            "name": habit.name,
            "description": habit.description,
            "icon": habit.icon,
            "color": try encoder.encode(habit.color),
            "habitType": habit.habitType.rawValue,
            "schedule": habit.schedule,
            "goal": habit.goal,
            "reminder": habit.reminder,
            "startDate": habit.startDate,
            "endDate": habit.endDate as Any,
            "createdAt": habit.createdAt,
            "reminders": try encoder.encode(habit.reminders),
            "baseline": habit.baseline,
            "target": habit.target,
            "completionHistory": habit.completionHistory,
            "completionStatus": habit.completionStatus,
            "completionTimestamps": habit.completionTimestamps,
            "difficultyHistory": habit.difficultyHistory,
            "actualUsage": habit.actualUsage
        ]
    }
    
    private func firestoreDataToHabit(_ data: [String: Any]) throws -> Habit {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let description = data["description"] as? String,
              let icon = data["icon"] as? String,
              let colorData = data["color"] as? Data,
              let color = try? decoder.decode(CodableColor.self, from: colorData),
              let habitTypeString = data["habitType"] as? String,
              let habitType = HabitType(rawValue: habitTypeString),
              let schedule = data["schedule"] as? String,
              let goal = data["goal"] as? String,
              let reminder = data["reminder"] as? String,
              let startDate = data["startDate"] as? Date,
              let createdAt = data["createdAt"] as? Date else {
            throw NSError(domain: "FirestoreHabitRepository", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid habit data"])
        }
        
        let endDate = data["endDate"] as? Date
        let reminders = (data["reminders"] as? Data).flatMap { try? decoder.decode([ReminderItem].self, from: $0) } ?? []
        let baseline = data["baseline"] as? Int ?? 0
        let target = data["target"] as? Int ?? 0
        let completionHistory = data["completionHistory"] as? [String: Int] ?? [:]
        let completionStatus = data["completionStatus"] as? [String: Bool] ?? [:]
        let completionTimestamps = data["completionTimestamps"] as? [String: [Date]] ?? [:]
        let difficultyHistory = data["difficultyHistory"] as? [String: Int] ?? [:]
        let actualUsage = data["actualUsage"] as? [String: Int] ?? [:]
        
        return Habit(
            id: id,
            name: name,
            description: description,
            icon: icon,
            color: color,
            habitType: habitType,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            reminders: reminders,
            baseline: baseline,
            target: target,
            completionHistory: completionHistory,
            completionStatus: completionStatus,
            completionTimestamps: completionTimestamps,
            difficultyHistory: difficultyHistory,
            actualUsage: actualUsage
        )
    }
}

// MARK: - Note: Using existing Habit model from Core/Models/Habit.swift
