import SwiftUI

// MARK: - Habit Storage Manager for Performance Optimization
class HabitStorageManager {
    static let shared = HabitStorageManager()
    private let userDefaults = UserDefaults.standard
    private let habitsKey = "SavedHabits"
    
    // Performance optimization: Cache loaded habits
    private var cachedHabits: [Habit]?
    private var lastSaveTime: Date = Date()
    private let saveDebounceInterval: TimeInterval = 0.5
    
    private init() {}
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) {
        // Performance optimization: Debounce saves to avoid excessive writes
        // But allow immediate saves when needed (e.g., new habit creation)
        if immediate {
            performSave(habits)
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastSaveTime) < saveDebounceInterval {
            // Schedule a delayed save
            DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval) {
                self.performSave(habits)
            }
            return
        }
        
        performSave(habits)
    }
    
    private func performSave(_ habits: [Habit]) {
        if let encoded = try? JSONEncoder().encode(habits) {
            userDefaults.set(encoded, forKey: habitsKey)
            cachedHabits = habits
            lastSaveTime = Date()
        }
    }
    
    func loadHabits() -> [Habit] {
        // Performance optimization: Return cached result if available
        if let cached = cachedHabits {
            return cached
        }
        
        if let data = userDefaults.data(forKey: habitsKey),
           let habits = try? JSONDecoder().decode([Habit].self, from: data) {
            cachedHabits = habits
            return habits
        }
        return []
    }
    
    func clearCache() {
        cachedHabits = nil
    }
}

struct Habit: Identifiable, Codable {
    var id = UUID()
    var name: String
    var description: String
    var icon: String // System icon name
    var color: Color
    var habitType: HabitType
    var schedule: String
    var goal: String
    var reminder: String // Keep for backward compatibility
    var reminders: [ReminderItem] = [] // New field for storing reminder items
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool = false
    var streak: Int = 0
    var createdAt: Date = Date()
    var completionHistory: [String: Int] = [:] // Track daily progress: "yyyy-MM-dd" -> Int (count of completions)
    
    // Habit Breaking specific properties
    var baseline: Int = 0 // Current average usage
    var target: Int = 0 // Target reduced amount
    var actualUsage: [String: Int] = [:] // Track actual usage: "yyyy-MM-dd" -> Int
    
    init(name: String, description: String, icon: String, color: Color, habitType: HabitType, schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil, isCompleted: Bool = false, streak: Int = 0, reminders: [ReminderItem] = [], baseline: Int = 0, target: Int = 0) {
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.habitType = habitType
        self.schedule = schedule
        self.goal = goal
        self.reminder = reminder
        self.reminders = reminders
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.streak = streak
        self.baseline = baseline
        self.target = target
    }
    
    init(from step1Data: (String, String, String, Color, HabitType), schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil, reminders: [ReminderItem] = [], baseline: Int = 0, target: Int = 0) {
        self.name = step1Data.0
        self.description = step1Data.1
        self.icon = step1Data.2
        self.color = step1Data.3
        self.habitType = step1Data.4
        self.schedule = schedule
        self.goal = goal
        self.reminder = reminder
        self.reminders = reminders
        self.startDate = startDate
        self.endDate = endDate
        self.baseline = baseline
        self.target = target
    }
    
    // MARK: - Completion History Methods
    mutating func markCompleted(for date: Date) {
        let dateKey = Self.dateKey(for: date)
        let currentProgress = completionHistory[dateKey] ?? 0
        completionHistory[dateKey] = currentProgress + 1
        updateCurrentCompletionStatus()
    }
    
    mutating func markIncomplete(for date: Date) {
        let dateKey = Self.dateKey(for: date)
        let currentProgress = completionHistory[dateKey] ?? 0
        completionHistory[dateKey] = max(0, currentProgress - 1)
        updateCurrentCompletionStatus()
    }
    
    func isCompleted(for date: Date) -> Bool {
        let dateKey = Self.dateKey(for: date)
        return (completionHistory[dateKey] ?? 0) > 0
    }
    
    func getProgress(for date: Date) -> Int {
        let dateKey = Self.dateKey(for: date)
        return completionHistory[dateKey] ?? 0
    }
    
    // MARK: - Habit Breaking Methods
    mutating func logActualUsage(_ amount: Int, for date: Date) {
        let dateKey = Self.dateKey(for: date)
        actualUsage[dateKey] = amount
    }
    
    func getActualUsage(for date: Date) -> Int {
        let dateKey = Self.dateKey(for: date)
        return actualUsage[dateKey] ?? 0
    }
    
    func calculateSuccessRate(for date: Date) -> Double {
        let actual = getActualUsage(for: date)
        
        if target == 0 {
            // Complete elimination
            return baseline > 0 ? Double(baseline - actual) / Double(baseline) * 100.0 : 0.0
        } else {
            // Partial reduction
            let reductionRange = baseline - target
            return reductionRange > 0 ? Double(baseline - actual) / Double(reductionRange) * 100.0 : 0.0
        }
    }
    
    func getProgressForHabitBreaking(for date: Date) -> Int {
        let successRate = calculateSuccessRate(for: date)
        return Int(successRate)
    }
    
    private mutating func updateCurrentCompletionStatus() {
        let today = Calendar.current.startOfDay(for: Date())
        isCompleted = isCompleted(for: today)
    }
    
    private static func dateKey(for date: Date) -> String {
        return DateUtils.dateKey(for: date)
    }
    
    // MARK: - Persistence Methods (Optimized)
    static func saveHabits(_ habits: [Habit], immediate: Bool = false) {
        HabitStorageManager.shared.saveHabits(habits, immediate: immediate)
    }
    
    static func loadHabits() -> [Habit] {
        return HabitStorageManager.shared.loadHabits()
    }
    
    static func clearCache() {
        HabitStorageManager.shared.clearCache()
    }
}

enum HabitType: String, CaseIterable, Codable {
    case formation = "Habit Formation"
    case breaking = "Habit Breaking"
}

// MARK: - Color Codable Extension
extension Color: Codable {
    // Performance optimization: Cache color hex values
    private static var hexCache: [Color: String] = [:]
    private static var colorCache: [String: Color] = [:]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        self.init(hex: hex)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toHex())
    }
    
    init(hex: String) {
        // Performance optimization: Use cached color if available
        if let cachedColor = Self.colorCache[hex] {
            self = cachedColor
            return
        }
        
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        let color = Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
        
        // Cache the color
        Self.colorCache[hex] = color
        self = color
    }
    
    func toHex() -> String {
        // Performance optimization: Use cached hex value if available
        if let cachedHex = Self.hexCache[self] {
            return cachedHex
        }
        
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let hex = String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        
        // Cache the hex value
        Self.hexCache[self] = hex
        return hex
    }
} 