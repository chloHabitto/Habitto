import Foundation
import SwiftData
import SwiftUI
import UIKit

/// HabitModel stores STATIC habit configuration
///
/// **Design Philosophy:**
/// - Contains only metadata and configuration
/// - NO progress data (that's in DailyProgressModel)
/// - NO streak data (that's in GlobalStreakModel)
/// - Immutable habit definition that rarely changes
///
/// **Relationships:**
/// - Has many DailyProgressModel records (one per day)
/// - Has many ReminderModel records
@Model
final class HabitModel {
    // MARK: - Identity
    
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// User ID for multi-user support and data isolation
    var userId: String
    
    // MARK: - Basic Information
    
    /// Habit name (e.g., "Morning Run", "Read Books")
    var name: String
    
    /// Optional description/notes
    var habitDescription: String
    
    /// SF Symbol or emoji icon name
    var icon: String
    
    /// Color encoded as Data (for SwiftData compatibility)
    var colorData: Data
    
    // MARK: - Habit Type
    
    /// Type: "Habit Building" or "Habit Breaking" (stored as String for SwiftData)
    var habitType: String
    
    // MARK: - Goal Configuration
    
    /// Goal number (e.g., 5 in "5 times per day")
    var goalCount: Int
    
    /// Goal unit (e.g., "times", "minutes", "pages")
    var goalUnit: String
    
    /// Schedule encoded as JSON Data
    /// **Why Data?** SwiftData doesn't support enum with associated values directly
    var scheduleData: Data
    
    // MARK: - Habit Breaking Specific (Optional)
    
    /// Baseline/current behavior for comparison (e.g., "Currently smoke 10 cigarettes/day")
    /// **Used ONLY for analytics, NOT for scheduling**
    var baselineCount: Int?
    
    /// Baseline unit (usually same as goalUnit)
    var baselineUnit: String?
    
    // MARK: - Date Range
    
    /// When habit tracking starts
    var startDate: Date
    
    /// When habit tracking ends (nil = no end date)
    var endDate: Date?
    
    // MARK: - Metadata
    
    /// When habit was created
    var createdAt: Date
    
    /// Last time habit was modified
    var updatedAt: Date
    
    // MARK: - Relationships
    
    /// Reminders for this habit
    @Relationship(deleteRule: .cascade) var reminders: [ReminderModel]
    
    /// Daily progress records (inverse relationship)
    /// **Note:** Inverse relationship means DailyProgressModel owns the relationship
    @Relationship(deleteRule: .cascade, inverse: \DailyProgressModel.habit)
    var progressRecords: [DailyProgressModel]
    
    // MARK: - Computed Properties
    
    /// Decoded Color for UI usage
    var color: Color {
        get { Self.decodeColor(colorData) }
        set { 
            colorData = Self.encodeColor(newValue)
            updatedAt = Date()
        }
    }
    
    /// Typed HabitType enum
    var habitTypeEnum: HabitType {
        get { HabitType(rawValue: habitType) ?? .formation }
        set { 
            habitType = newValue.rawValue
            updatedAt = Date()
        }
    }
    
    /// Decoded Schedule enum
    var schedule: HabitSchedule {
        get { 
            guard let decoded = try? JSONDecoder().decode(HabitSchedule.self, from: scheduleData) 
            else { 
                print("⚠️ Failed to decode schedule, defaulting to .daily")
                return .daily 
            }
            return decoded
        }
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else {
                print("⚠️ Failed to encode schedule")
                return
            }
            scheduleData = encoded
            updatedAt = Date()
        }
    }
    
    /// Check if this is a frequency-based schedule
    var isFrequencyBased: Bool {
        schedule.isFrequencyBased
    }
    
    /// Check if habit is active (not ended)
    var isActive: Bool {
        if let end = endDate {
            return Date() <= end
        }
        return true
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        userId: String,
        name: String,
        habitDescription: String = "",
        icon: String,
        color: Color,
        habitType: HabitType,
        goalCount: Int,
        goalUnit: String,
        schedule: HabitSchedule,
        baselineCount: Int? = nil,
        baselineUnit: String? = nil,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.habitDescription = habitDescription
        self.icon = icon
        self.colorData = Self.encodeColor(color)
        self.habitType = habitType.rawValue
        self.goalCount = goalCount
        self.goalUnit = goalUnit
        
        // Encode schedule
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
        
        self.baselineCount = baselineCount
        self.baselineUnit = baselineUnit
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = endDate.map { Calendar.current.startOfDay(for: $0) }
        self.createdAt = Date()
        self.updatedAt = Date()
        self.reminders = []
        self.progressRecords = []
    }
    
    // MARK: - Helper Methods
    
    /// Check if habit should appear on given date
    func shouldAppear(on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        
        // Check date range
        guard targetDate >= start else { return false }
        
        if let end = endDate {
            let endNormalized = calendar.startOfDay(for: end)
            guard targetDate <= endNormalized else { return false }
        }
        
        // Check schedule
        return schedule.shouldAppear(on: date, habitStartDate: startDate)
    }
    
    /// Update habit metadata (triggers updatedAt)
    func updateMetadata(
        name: String? = nil,
        description: String? = nil,
        icon: String? = nil,
        color: Color? = nil
    ) {
        if let name = name { self.name = name }
        if let description = description { self.habitDescription = description }
        if let icon = icon { self.icon = icon }
        if let color = color { self.color = color }
        self.updatedAt = Date()
    }
    
    /// Update goal configuration
    func updateGoal(
        count: Int? = nil,
        unit: String? = nil,
        schedule: HabitSchedule? = nil
    ) {
        if let count = count { self.goalCount = count }
        if let unit = unit { self.goalUnit = unit }
        if let schedule = schedule { self.schedule = schedule }
        self.updatedAt = Date()
    }
    
    // MARK: - Color Encoding/Decoding
    
    /// Encode Color to Data using JSON (modern, Codable-friendly)
    static func encodeColor(_ color: Color) -> Data {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Convert to Double array for JSON encoding
        let components = [Double(red), Double(green), Double(blue), Double(alpha)]
        
        guard let encoded = try? JSONEncoder().encode(components) else {
            print("⚠️ Failed to encode color, using default")
            return Data()
        }
        
        return encoded
    }
    
    /// Decode Data to Color using JSON (modern, Codable-friendly)
    static func decodeColor(_ data: Data) -> Color {
        guard !data.isEmpty,
              let components = try? JSONDecoder().decode([Double].self, from: data),
              components.count == 4
        else {
            print("⚠️ Failed to decode color, using default blue")
            return .blue  // Default fallback
        }
        
        return Color(
            red: components[0],
            green: components[1],
            blue: components[2],
            opacity: components[3]
        )
    }
}

// MARK: - Validation

extension HabitModel {
    /// Validate habit configuration
    /// - Returns: Validation errors, or empty array if valid
    func validate() -> [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Habit name cannot be empty")
        }
        
        if goalCount <= 0 {
            errors.append("Goal count must be greater than 0")
        }
        
        if goalUnit.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Goal unit cannot be empty")
        }
        
        if let end = endDate, end < startDate {
            errors.append("End date cannot be before start date")
        }
        
        if habitTypeEnum == .breaking {
            if let baseline = baselineCount {
                if baseline <= goalCount {
                    errors.append("For habit breaking, baseline must be greater than goal")
                }
            }
        }
        
        return errors
    }
    
    var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Migration Helpers

extension HabitModel {
    /// Create from legacy Habit model
    static func fromLegacy(
        _ oldHabit: Habit,
        userId: String
    ) -> HabitModel {
        // Parse old goal string: "5 times every day"
        let goalComponents = parseGoalString(oldHabit.goal)
        
        // Parse old schedule string: "Everyday", "Monday, Wednesday", etc.
        let schedule = HabitSchedule.fromLegacyString(oldHabit.schedule)
        
        return HabitModel(
            id: oldHabit.id,
            userId: userId,
            name: oldHabit.name,
            habitDescription: oldHabit.description,
            icon: oldHabit.icon,
            color: oldHabit.color.color,
            habitType: oldHabit.habitType,
            goalCount: goalComponents.count,
            goalUnit: goalComponents.unit,
            schedule: schedule,
            baselineCount: oldHabit.baseline > 0 ? oldHabit.baseline : nil,
            baselineUnit: goalComponents.unit,
            startDate: oldHabit.startDate,
            endDate: oldHabit.endDate
        )
    }
    
    private static func parseGoalString(_ goalString: String) -> (count: Int, unit: String) {
        // Parse strings like "5 times every day", "30 minutes per day", etc.
        let components = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let count = components.compactMap { Int($0) }.first ?? 1
        
        // Extract unit (word after the number)
        let pattern = #"(\d+)\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: goalString, range: NSRange(goalString.startIndex..., in: goalString)),
           let unitRange = Range(match.range(at: 2), in: goalString) {
            let unit = String(goalString[unitRange])
            return (count, unit)
        }
        
        return (count, "time")  // Default
    }
}

