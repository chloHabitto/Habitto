import Foundation

// MARK: - TextSanitizer

/// Handles text normalization and sanitization for data integrity
class TextSanitizer {
  /// Normalize text to NFC (Canonical Decomposition, followed by Canonical Composition)
  /// This prevents duplicate keys from different Unicode representations
  static func normalizeNFC(_ text: String) -> String {
    text.precomposedStringWithCanonicalMapping
  }

  /// Sanitize user input text for safe storage
  /// - Parameter text: Raw user input text
  /// - Returns: Sanitized text safe for storage
  static func sanitizeUserInput(_ text: String) -> String {
    // 1. Normalize to NFC
    let normalized = normalizeNFC(text)

    // 2. Trim whitespace and newlines
    let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

    // 3. Remove control characters (except common ones like newline, tab)
    let controlCharacterSet = CharacterSet.controlCharacters.subtracting([
      "\n", "\t", "\r" // Keep common whitespace characters
    ])
    let sanitized = trimmed.components(separatedBy: controlCharacterSet).joined()

    return sanitized
  }

  /// Validate that text contains only safe characters for storage
  /// - Parameter text: Text to validate
  /// - Returns: True if text is safe for storage
  static func isValidForStorage(_ text: String) -> Bool {
    // Check for null bytes or other dangerous characters
    if text.contains("\0") {
      return false
    }

    // Check for extremely long strings (prevent DoS)
    if text.count > 10000 {
      return false
    }

    // Check for valid UTF-8 encoding
    guard text.canBeConverted(to: .utf8) else {
      return false
    }

    return true
  }

  /// Create a safe key from user input (for use in dictionaries, etc.)
  /// - Parameter text: User input text
  /// - Returns: Safe key for storage
  static func createSafeKey(from text: String) -> String {
    let sanitized = sanitizeUserInput(text)

    // Convert to lowercase for consistency
    let lowercase = sanitized.lowercased()

    // Replace spaces with underscores
    let key = lowercase.replacingOccurrences(of: " ", with: "_")

    // Remove any remaining unsafe characters
    let safeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
    let safeKey = key.components(separatedBy: safeCharacters.inverted).joined()

    // Ensure key is not empty
    if safeKey.isEmpty {
      return "unnamed_\(UUID().uuidString.prefix(8))"
    }

    return safeKey
  }

  /// Normalize and validate habit name
  /// - Parameter name: Raw habit name
  /// - Returns: Sanitized habit name
  /// - Throws: Error if name is invalid
  static func sanitizeHabitName(_ name: String) throws -> String {
    let sanitized = sanitizeUserInput(name)

    if sanitized.isEmpty {
      throw TextSanitizerError.emptyName
    }

    if !isValidForStorage(sanitized) {
      throw TextSanitizerError.invalidCharacters
    }

    return sanitized
  }

  /// Normalize and validate habit description
  /// - Parameter description: Raw habit description
  /// - Returns: Sanitized habit description
  static func sanitizeHabitDescription(_ description: String) -> String {
    let sanitized = sanitizeUserInput(description)

    // Descriptions can be empty, so just return sanitized version
    return sanitized
  }

  /// Normalize and validate reminder text
  /// - Parameter reminder: Raw reminder text
  /// - Returns: Sanitized reminder text
  static func sanitizeReminderText(_ reminder: String) -> String {
    let sanitized = sanitizeUserInput(reminder)

    // Reminders can be empty, so just return sanitized version
    return sanitized
  }
}

// MARK: - TextSanitizerError

enum TextSanitizerError: LocalizedError {
  case emptyName
  case invalidCharacters
  case tooLong

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .emptyName:
      "Habit name cannot be empty"
    case .invalidCharacters:
      "Habit name contains invalid characters"
    case .tooLong:
      "Habit name is too long"
    }
  }
}

// MARK: - Habit Text Sanitization Extension

extension Habit {
  /// Create a new habit with sanitized text fields
  /// - Parameter habit: Original habit
  /// - Returns: New habit with sanitized text
  /// - Throws: Error if sanitization fails
  static func withSanitizedText(from habit: Habit) throws -> Habit {
    let sanitizedName = try TextSanitizer.sanitizeHabitName(habit.name)
    let sanitizedDescription = TextSanitizer.sanitizeHabitDescription(habit.description)
    let sanitizedReminder = TextSanitizer.sanitizeReminderText(habit.reminder)

    return Habit(
      id: habit.id,
      name: sanitizedName,
      description: sanitizedDescription,
      icon: habit.icon,
      color: habit.color,
      habitType: habit.habitType,
      schedule: habit.schedule,
      goal: habit.goal,
      reminder: sanitizedReminder,
      startDate: habit.startDate,
      endDate: habit.endDate,
      createdAt: habit.createdAt,
      reminders: habit.reminders.map { reminder in
        ReminderItem(
          id: reminder.id,
          time: reminder.time,
          isActive: reminder.isActive)
      },
      baseline: habit.baseline,
      target: habit.target,
      completionHistory: habit.completionHistory,
      difficultyHistory: habit.difficultyHistory,
      actualUsage: habit.actualUsage)
  }
}

// MARK: - ReminderItem Text Sanitization Extension

extension ReminderItem {
  /// Create a new reminder with sanitized text fields
  /// - Parameter reminder: Original reminder
  /// - Returns: New reminder with sanitized text
  static func withSanitizedText(from reminder: ReminderItem) -> ReminderItem {
    ReminderItem(
      id: reminder.id,
      time: reminder.time,
      isActive: reminder.isActive)
  }
}
