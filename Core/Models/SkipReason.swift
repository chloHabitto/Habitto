import Foundation

// MARK: - SkipReason

/// Represents the reason why a habit was skipped on a particular day
enum SkipReason: String, Codable, CaseIterable, Equatable {
  case medical
  case travel
  case equipment
  case weather
  case emergency
  case rest
  case other
  
  /// Display string for the skip reason
  var rawValue: String {
    switch self {
    case .medical:
      return "Medical/Health"
    case .travel:
      return "Travel"
    case .equipment:
      return "Equipment Unavailable"
    case .weather:
      return "Weather"
    case .emergency:
      return "Emergency"
    case .rest:
      return "Rest Day"
    case .other:
      return "Other"
    }
  }
  
  /// Icon name for the skip reason
  var icon: String {
    switch self {
    case .medical:
      return "Icon-MedicalKit_Filled"
    case .travel:
      return "Icon-Plane_Filled"
    case .equipment:
      return "Icon-Tools_Filled"
    case .weather:
      return "cloud.rain.fill"
    case .emergency:
      return "Icon-DangerTriangle_Filled"
    case .rest:
      return "Icon-Bed_Filled"
    case .other:
      return "ellipsis.circle.fill"
    }
  }
  
  /// Whether this icon is a custom asset (true) or SF Symbol (false)
  var isCustomIcon: Bool {
    switch self {
    case .medical, .travel, .equipment, .emergency, .rest:
      return true
    case .weather, .other:
      return false
    }
  }
  
  /// Short label for compact display
  var shortLabel: String {
    switch self {
    case .medical:
      return "Medical"
    case .travel:
      return "Travel"
    case .equipment:
      return "Equipment"
    case .weather:
      return "Weather"
    case .emergency:
      return "Emergency"
    case .rest:
      return "Rest"
    case .other:
      return "Other"
    }
  }
}

// MARK: - HabitSkip

/// Represents a skipped day for a habit with reason and optional note
struct HabitSkip: Codable, Equatable {
  /// ID of the habit that was skipped
  let habitId: UUID
  
  /// Date key in format "yyyy-MM-dd"
  let dateKey: String
  
  /// Reason for skipping
  let reason: SkipReason
  
  /// Optional custom note for additional context
  let customNote: String?
  
  /// When this skip was recorded
  let createdAt: Date
  
  /// Convenience initializer
  init(
    habitId: UUID,
    dateKey: String,
    reason: SkipReason,
    customNote: String? = nil,
    createdAt: Date = Date()
  ) {
    self.habitId = habitId
    self.dateKey = dateKey
    self.reason = reason
    self.customNote = customNote
    self.createdAt = createdAt
  }
}
