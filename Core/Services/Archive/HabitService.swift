import Foundation
import SwiftData
import SwiftUI

/// Service for managing habits (CRUD operations)
/// **Responsibilities:**
/// - Create, read, update, delete habits
/// - Query habits by user, date, status
/// - Validate habit data
/// - Manage habit lifecycle
@MainActor
class HabitService {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("✅ HabitService: Initialized")
    }
    
    // MARK: - Create
    
    /// Create a new habit
    /// **Validates:** habit data before saving
    /// **Side effects:** Inserts into database
    func createHabit(_ habit: HabitModel) throws {
        // Validate habit
        let errors = habit.validate()
        guard errors.isEmpty else {
            print("❌ HabitService: Validation failed for '\(habit.name)'")
            for error in errors {
                print("   - \(error)")
            }
            throw HabitError.validationFailed(errors)
        }
        
        modelContext.insert(habit)
        try modelContext.save()
        
        print("✨ HabitService: Created habit '\(habit.name)' (ID: \(habit.id))")
    }
    
    /// Create multiple habits in a batch
    func createHabits(_ habits: [HabitModel]) throws {
        for habit in habits {
            let errors = habit.validate()
            guard errors.isEmpty else {
                throw HabitError.validationFailed(errors)
            }
            modelContext.insert(habit)
        }
        
        try modelContext.save()
        print("✨ HabitService: Created \(habits.count) habits")
    }
    
    // MARK: - Read
    
    /// Get a habit by ID
    func getHabit(id: UUID) throws -> HabitModel? {
        let descriptor = FetchDescriptor<HabitModel>(
            predicate: #Predicate { habit in
                habit.id == id
            }
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    /// Get all habits for a user
    /// **Returns:** Array of habits sorted by creation date
    func getHabits(for userId: String) throws -> [HabitModel] {
        let descriptor = FetchDescriptor<HabitModel>(
            predicate: #Predicate { habit in
                habit.userId == userId
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        let habits = try modelContext.fetch(descriptor)
        print("📋 HabitService: Found \(habits.count) habits for user '\(userId)'")
        return habits
    }
    
    /// Get active habits for a user on a specific date
    /// **Filters:**
    /// - Habit started before/on this date
    /// - Habit not ended (or ended after this date)
    /// - Habit scheduled to appear on this date
    func getActiveHabits(
        for userId: String,
        on date: Date
    ) throws -> [HabitModel] {
        let normalizedDate = DateUtils.startOfDay(for: date)
        
        // Get all habits for user
        let allHabits = try getHabits(for: userId)
        
        // Filter to active habits on this date
        let activeHabits = allHabits.filter { habit in
            // Check if habit has started
            guard habit.startDate <= normalizedDate else {
                return false
            }
            
            // Check if habit has ended
            if let endDate = habit.endDate, endDate < normalizedDate {
                return false
            }
            
            // Check if habit is scheduled for this date
            return habit.schedule.shouldAppear(on: normalizedDate, habitStartDate: habit.startDate)
        }
        
        let dateKey = DateUtils.dateKey(for: normalizedDate)
        print("📋 HabitService: Found \(activeHabits.count)/\(allHabits.count) active habits on \(dateKey)")
        
        return activeHabits
    }
    
    /// Get habits by type (formation or breaking)
    func getHabits(
        for userId: String,
        type: HabitType
    ) throws -> [HabitModel] {
        let allHabits = try getHabits(for: userId)
        return allHabits.filter { $0.habitTypeEnum == type }
    }
    
    /// Get habits with a specific schedule pattern
    func getHabits(
        for userId: String,
        matchingSchedule matcher: (HabitSchedule) -> Bool
    ) throws -> [HabitModel] {
        let allHabits = try getHabits(for: userId)
        return allHabits.filter { matcher($0.schedule) }
    }
    
    /// Get daily habits
    func getDailyHabits(for userId: String) throws -> [HabitModel] {
        return try getHabits(for: userId, matchingSchedule: { schedule in
            if case .daily = schedule { return true }
            return false
        })
    }
    
    // MARK: - Update
    
    /// Update an existing habit
    /// **Validates:** updated data before saving
    /// **Note:** Updates the updatedAt timestamp automatically
    func updateHabit(_ habit: HabitModel) throws {
        // Validate habit
        let errors = habit.validate()
        guard errors.isEmpty else {
            print("❌ HabitService: Validation failed for '\(habit.name)'")
            throw HabitError.validationFailed(errors)
        }
        
        // Update timestamp
        habit.updatedAt = Date()
        
        try modelContext.save()
        print("✏️ HabitService: Updated habit '\(habit.name)' (ID: \(habit.id))")
    }
    
    /// Update habit goal
    func updateGoal(
        for habit: HabitModel,
        count: Int? = nil,
        unit: String? = nil,
        schedule: HabitSchedule? = nil
    ) throws {
        habit.updateGoal(count: count, unit: unit, schedule: schedule)
        try modelContext.save()
        
        print("🎯 HabitService: Updated goal for '\(habit.name)'")
    }
    
    /// Update habit appearance
    func updateAppearance(
        for habit: HabitModel,
        name: String? = nil,
        description: String? = nil,
        icon: String? = nil,
        color: Color? = nil
    ) throws {
        if let name = name { habit.name = name }
        if let description = description { habit.habitDescription = description }
        if let icon = icon { habit.icon = icon }
        if let color = color { habit.color = color }
        habit.updatedAt = Date()
        
        try modelContext.save()
        
        print("🎨 HabitService: Updated appearance for '\(habit.name)'")
    }
    
    // MARK: - Delete
    
    /// Delete a habit
    /// **Warning:** This will cascade delete all related progress records!
    /// **Side effects:** Removes habit and all DailyProgressModel records
    func deleteHabit(_ habit: HabitModel) throws {
        let habitName = habit.name
        let habitId = habit.id
        
        // Delete the habit (cascade will delete progress records)
        modelContext.delete(habit)
        try modelContext.save()
        
        print("🗑️ HabitService: Deleted habit '\(habitName)' (ID: \(habitId))")
    }
    
    /// Delete multiple habits
    func deleteHabits(_ habits: [HabitModel]) throws {
        for habit in habits {
            modelContext.delete(habit)
        }
        
        try modelContext.save()
        print("🗑️ HabitService: Deleted \(habits.count) habits")
    }
    
    /// Delete all habits for a user
    /// **Warning:** This is irreversible!
    func deleteAllHabits(for userId: String) throws {
        let habits = try getHabits(for: userId)
        
        for habit in habits {
            modelContext.delete(habit)
        }
        
        try modelContext.save()
        print("🗑️ HabitService: Deleted all \(habits.count) habits for user '\(userId)'")
    }
    
    // MARK: - Queries
    
    /// Check if habit should appear on a specific date
    func shouldAppear(
        habit: HabitModel,
        on date: Date
    ) -> Bool {
        let normalizedDate = DateUtils.startOfDay(for: date)
        
        // Check start date
        guard habit.startDate <= normalizedDate else {
            return false
        }
        
        // Check end date
        if let endDate = habit.endDate, endDate < normalizedDate {
            return false
        }
        
        // Check schedule
        return habit.schedule.shouldAppear(on: normalizedDate, habitStartDate: habit.startDate)
    }
    
    /// Get count of habits for a user
    func getHabitCount(for userId: String) throws -> Int {
        let descriptor = FetchDescriptor<HabitModel>(
            predicate: #Predicate { habit in
                habit.userId == userId
            }
        )
        
        return try modelContext.fetchCount(descriptor)
    }
    
    /// Check if user has any habits
    func hasHabits(userId: String) throws -> Bool {
        return try getHabitCount(for: userId) > 0
    }
    
    // MARK: - Search
    
    /// Search habits by name
    func searchHabits(
        for userId: String,
        query: String
    ) throws -> [HabitModel] {
        let allHabits = try getHabits(for: userId)
        let lowercaseQuery = query.lowercased()
        
        return allHabits.filter { habit in
            habit.name.lowercased().contains(lowercaseQuery) ||
            habit.habitDescription.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Validation
    
    /// Validate habit data without saving
    /// **Returns:** Array of validation errors (empty if valid)
    func validateHabit(_ habit: HabitModel) -> [String] {
        return habit.validate()
    }
    
    /// Check if habit is valid
    func isValid(_ habit: HabitModel) -> Bool {
        return habit.isValid
    }
}

// MARK: - Errors

enum HabitError: LocalizedError {
    case habitNotFound
    case validationFailed([String])
    case duplicateHabit
    case invalidSchedule
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .habitNotFound:
            return "Habit not found"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .duplicateHabit:
            return "A habit with this name already exists"
        case .invalidSchedule:
            return "Invalid habit schedule"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}

