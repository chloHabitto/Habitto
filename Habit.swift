import SwiftUI

struct Habit: Identifiable, Codable {
    var id = UUID()
    var name: String
    var description: String
    var icon: String // System icon name
    var color: Color
    var habitType: HabitType
    var schedule: String
    var goal: String
    var reminder: String
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool = false
    var streak: Int = 0
    var createdAt: Date = Date()
    
    init(name: String, description: String, icon: String, color: Color, habitType: HabitType, schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil, isCompleted: Bool = false, streak: Int = 0) {
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
    }
    
    init(from step1Data: (String, String, String, Color, HabitType), schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil) {
        self.name = step1Data.0
        self.description = step1Data.1
        self.icon = step1Data.2
        self.color = step1Data.3
        self.habitType = step1Data.4
        self.schedule = schedule
        self.goal = goal
        self.reminder = reminder
        self.startDate = startDate
        self.endDate = endDate
    }
    
    // MARK: - Persistence Methods
    static func saveHabits(_ habits: [Habit]) {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: "SavedHabits")
        }
    }
    
    static func loadHabits() -> [Habit] {
        if let data = UserDefaults.standard.data(forKey: "SavedHabits"),
           let habits = try? JSONDecoder().decode([Habit].self, from: data) {
            return habits
        }
        return []
    }
}

enum HabitType: String, CaseIterable, Codable {
    case formation = "Habit Formation"
    case breaking = "Habit Breaking"
}

// MARK: - Color Codable Extension
extension Color: Codable {
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
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var hex = String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        return hex
    }
} 