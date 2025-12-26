import Foundation

/// Determines how habit completion is evaluated for streak/XP purposes ONLY.
/// This does NOT affect UI display (checkmarks, calendars, progress charts).
enum CompletionMode: String, Codable, CaseIterable, Identifiable {
    case full      // progress >= goal (current strict behavior)
    case partial   // progress > 0 (lenient "any progress" mode)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .full: return "Full Completion"
        case .partial: return "Any Progress"
        }
    }
    
    var description: String {
        switch self {
        case .full: return "Streak and XP awarded only when all habits are 100% complete"
        case .partial: return "Streak and XP awarded as long as you made some progress on each habit"
        }
    }
    
    // MARK: - Storage
    
    private static let storageKey = "streak_completion_mode"
    
    /// Current streak mode setting (persisted in UserDefaults)
    static var current: CompletionMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey),
                  let mode = CompletionMode(rawValue: raw) else {
                return .full // Default to current strict behavior
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
            // Post notification so streak can recalculate if needed
            NotificationCenter.default.post(name: .streakModeDidChange, object: newValue)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let streakModeDidChange = Notification.Name("streakModeDidChange")
}

