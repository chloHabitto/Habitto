import Foundation
import SwiftUI

// MARK: - Secure Habit Model
// Enhanced Habit model with field-level encryption for sensitive data

struct SecureHabit: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var icon: String
    var color: Color
    var habitType: HabitType
    var schedule: String
    var goal: String
    var reminder: String
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    var streak: Int
    var createdAt: Date
    var reminders: [ReminderItem]
    var baseline: Int
    var target: Int
    var completionHistory: [String: Int]
    var difficultyHistory: [String: Int]
    var actualUsage: [String: Int]
    
    // MARK: - Sensitive Fields (encrypted)
    @SecureField private var notes: String
    @SecureField private var personalGoals: String
    @SecureField private var motivation: String
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        icon: String,
        color: Color,
        habitType: HabitType,
        schedule: String,
        goal: String,
        reminder: String,
        startDate: Date,
        endDate: Date? = nil,
        isCompleted: Bool = false,
        streak: Int = 0,
        createdAt: Date = Date(),
        reminders: [ReminderItem] = [],
        baseline: Int = 0,
        target: Int = 0,
        completionHistory: [String: Int] = [:],
        difficultyHistory: [String: Int] = [:],
        actualUsage: [String: Int] = [:],
        notes: String = "",
        personalGoals: String = "",
        motivation: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.habitType = habitType
        self.schedule = schedule
        self.goal = goal
        self.reminder = reminder
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.streak = streak
        self.createdAt = createdAt
        self.reminders = reminders
        self.baseline = baseline
        self.target = target
        self.completionHistory = completionHistory
        self.difficultyHistory = difficultyHistory
        self.actualUsage = actualUsage
        
        // Initialize secure fields
        self._notes = SecureField(wrappedValue: notes)
        self._personalGoals = SecureField(wrappedValue: personalGoals)
        self._motivation = SecureField(wrappedValue: motivation)
    }
    
    // MARK: - Secure Field Access
    
    mutating func getNotes() async throws -> String {
        return try await _notes.getValue()
    }
    
    mutating func setNotes(_ value: String) async throws {
        try await _notes.setValue(value)
    }
    
    mutating func getPersonalGoals() async throws -> String {
        return try await _personalGoals.getValue()
    }
    
    mutating func setPersonalGoals(_ value: String) async throws {
        try await _personalGoals.setValue(value)
    }
    
    mutating func getMotivation() async throws -> String {
        return try await _motivation.getValue()
    }
    
    mutating func setMotivation(_ value: String) async throws {
        try await _motivation.setValue(value)
    }
    
    // MARK: - Convenience Methods
    
    func isCompleted(for date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return completionHistory[dateString] ?? 0 > 0
    }
    
    func markCompleted(for date: Date) -> SecureHabit {
        var updatedHabit = self
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        updatedHabit.completionHistory[dateString] = 1
        updatedHabit.streak = calculateStreak()
        return updatedHabit
    }
    
    func markIncompleted(for date: Date) -> SecureHabit {
        var updatedHabit = self
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        updatedHabit.completionHistory.removeValue(forKey: dateString)
        updatedHabit.streak = calculateStreak()
        return updatedHabit
    }
    
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        let today = Date()
        var streak = 0
        
        for i in 0..<365 { // Check up to 1 year back
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: date)
            
            if completionHistory[dateString] ?? 0 > 0 {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Encryption Support
    
    func encryptSensitiveFields() async throws -> EncryptedSecureHabit {
        let encryptionManager = FieldLevelEncryptionManager.shared
        
        let encryptedFields = try await encryptionManager.encryptSensitiveFields(
            self,
            fieldPaths: [
                "notes",
                "personalGoals", 
                "motivation"
            ]
        )
        
        return EncryptedSecureHabit(
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
            isCompleted: isCompleted,
            streak: streak,
            createdAt: createdAt,
            reminders: reminders,
            baseline: baseline,
            target: target,
            completionHistory: completionHistory,
            difficultyHistory: difficultyHistory,
            actualUsage: actualUsage,
            encryptedSensitiveData: encryptedFields
        )
    }
}

// MARK: - Encrypted Habit Model

struct EncryptedSecureHabit: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var icon: String
    var color: Color
    var habitType: HabitType
    var schedule: String
    var goal: String
    var reminder: String
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    var streak: Int
    var createdAt: Date
    var reminders: [ReminderItem]
    var baseline: Int
    var target: Int
    var completionHistory: [String: Int]
    var difficultyHistory: [String: Int]
    var actualUsage: [String: Int]
    
    // Encrypted sensitive data
    let encryptedSensitiveData: EncryptedObject<SecureHabit>
    
    // MARK: - Decryption Support
    
    func decrypt() async throws -> SecureHabit {
        let encryptionManager = FieldLevelEncryptionManager.shared
        return try await encryptionManager.decryptSensitiveFields(encryptedSensitiveData)
    }
}

// MARK: - Secure Field Property Wrapper

@propertyWrapper
struct SecureField: Codable, Equatable {
    private var encryptedField: EncryptedField?
    private var cachedValue: String?
    private let fieldIdentifier: String
    
    init(wrappedValue: String = "") {
        self.fieldIdentifier = UUID().uuidString
        self.cachedValue = wrappedValue
    }
    
    var wrappedValue: String {
        get {
            // This will throw an error if accessed synchronously
            // Should use getValue() method instead
            fatalError("SecureField must be accessed asynchronously using getValue()")
        }
        set {
            // This will throw an error if set synchronously
            // Should use setValue() method instead
            fatalError("SecureField must be set asynchronously using setValue()")
        }
    }
    
    mutating func getValue() async throws -> String {
        // Return cached value if available
        if let cached = cachedValue {
            return cached
        }
        
        // Decrypt if encrypted field exists
        if let encrypted = encryptedField {
            let encryptionManager = FieldLevelEncryptionManager.shared
            let decryptedValue = try await encryptionManager.decryptField(encrypted)
            cachedValue = decryptedValue
            return decryptedValue
        }
        
        // Return empty string if no value
        return ""
    }
    
    mutating func setValue(_ value: String) async throws {
        let encryptionManager = FieldLevelEncryptionManager.shared
        encryptedField = try await encryptionManager.encryptField(value)
        cachedValue = value
    }
    
    mutating func clearCache() {
        cachedValue = nil
    }
    
    // MARK: - Codable Support
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.fieldIdentifier = UUID().uuidString
        self.encryptedField = try? container.decode(EncryptedField.self)
        self.cachedValue = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(encryptedField)
    }
    
    static func == (lhs: SecureField, rhs: SecureField) -> Bool {
        // Compare field identifiers for equality
        return lhs.fieldIdentifier == rhs.fieldIdentifier
    }
}

// MARK: - Secure Habit Repository

@MainActor
class SecureHabitRepository: ObservableObject {
    static let shared = SecureHabitRepository()
    
    @Published var habits: [SecureHabit] = []
    private let storageManager = SecureHabitStorageManager.shared
    
    private init() {
        loadHabits()
    }
    
    func loadHabits() {
        Task {
            do {
                habits = try await storageManager.loadHabits()
            } catch {
                print("❌ Failed to load secure habits: \(error)")
                habits = []
            }
        }
    }
    
    func saveHabits() async throws {
        try await storageManager.saveHabits(habits)
    }
    
    func addHabit(_ habit: SecureHabit) async throws {
        habits.append(habit)
        try await saveHabits()
    }
    
    func updateHabit(_ habit: SecureHabit) async throws {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            try await saveHabits()
        }
    }
    
    func deleteHabit(_ habit: SecureHabit) async throws {
        habits.removeAll { $0.id == habit.id }
        try await saveHabits()
    }
}

// MARK: - Secure Storage Manager

actor SecureHabitStorageManager {
    static let shared = SecureHabitStorageManager()
    
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    private init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func loadHabits() async throws -> [SecureHabit] {
        let habitsURL = documentsURL.appendingPathComponent("secure_habits.json")
        
        guard fileManager.fileExists(atPath: habitsURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: habitsURL)
        let encryptedHabits = try JSONDecoder().decode([EncryptedSecureHabit].self, from: data)
        
        // Decrypt all habits
        var decryptedHabits: [SecureHabit] = []
        for encryptedHabit in encryptedHabits {
            let decryptedHabit = try await encryptedHabit.decrypt()
            decryptedHabits.append(decryptedHabit)
        }
        
        return decryptedHabits
    }
    
    func saveHabits(_ habits: [SecureHabit]) async throws {
        // Encrypt all habits
        var encryptedHabits: [EncryptedSecureHabit] = []
        for habit in habits {
            let encryptedHabit = try await habit.encryptSensitiveFields()
            encryptedHabits.append(encryptedHabit)
        }
        
        // Save encrypted data
        let data = try JSONEncoder().encode(encryptedHabits)
        let habitsURL = documentsURL.appendingPathComponent("secure_habits.json")
        
        // Apply file protection
        try data.write(to: habitsURL)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: habitsURL.path
        )
    }
}
