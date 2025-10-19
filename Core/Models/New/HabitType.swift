import Foundation

/// Type of habit tracking
enum HabitType: String, Codable, CaseIterable, Hashable {
    case formation = "Habit Building"
    case breaking = "Habit Breaking"
    
    var displayName: String {
        rawValue
    }
    
    var isFormation: Bool {
        self == .formation
    }
    
    var isBreaking: Bool {
        self == .breaking
    }
}

