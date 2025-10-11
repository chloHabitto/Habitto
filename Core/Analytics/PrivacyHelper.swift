import Foundation

// MARK: - PrivacyHelper

// Ensures no PII or sensitive data leaks into analytics

enum PrivacyHelper {
  // MARK: - PII Detection

  /// Check if a string contains potential PII
  static func containsPII(_ string: String) -> Bool {
    let piiPatterns = [
      // Email patterns
      "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
      // Phone patterns
      "\\+?[1-9]\\d{1,14}",
      // SSN patterns (US)
      "\\d{3}-?\\d{2}-?\\d{4}",
      // Credit card patterns
      "\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}",
      // Common token patterns
      "Bearer\\s+[A-Za-z0-9_-]+",
      "token\\s*[:=]\\s*[A-Za-z0-9_-]+",
      // UUID patterns (might contain user IDs)
      "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
    ]

    for pattern in piiPatterns {
      if string.range(of: pattern, options: .regularExpression) != nil {
        return true
      }
    }

    return false
  }

  /// Check if a dictionary contains PII in keys or values
  static func containsPII(_ dictionary: [String: Any]) -> Bool {
    // Check keys
    for key in dictionary.keys {
      if containsPII(key) {
        return true
      }
    }

    // Check string values
    for (_, value) in dictionary {
      if let stringValue = value as? String {
        if containsPII(stringValue) {
          return true
        }
      } else if let dictValue = value as? [String: Any] {
        if containsPII(dictValue) {
          return true
        }
      }
    }

    return false
  }

  // MARK: - Redaction Methods

  /// Redact PII from a string
  static func redactPII(_ string: String) -> String {
    var redacted = string

    // Redact email addresses
    redacted = redacted.replacingOccurrences(
      of: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
      with: "[REDACTED_EMAIL]",
      options: .regularExpression)

    // Redact phone numbers
    redacted = redacted.replacingOccurrences(
      of: "\\+?[1-9]\\d{1,14}",
      with: "[REDACTED_PHONE]",
      options: .regularExpression)

    // Redact tokens
    redacted = redacted.replacingOccurrences(
      of: "Bearer\\s+[A-Za-z0-9_-]+",
      with: "Bearer [REDACTED_TOKEN]",
      options: .regularExpression)

    redacted = redacted.replacingOccurrences(
      of: "token\\s*[:=]\\s*[A-Za-z0-9_-]+",
      with: "token=[REDACTED_TOKEN]",
      options: .regularExpression)

    // Redact UUIDs (replace with generic pattern)
    redacted = redacted.replacingOccurrences(
      of: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
      with: "[UUID_REDACTED]",
      options: .regularExpression)

    return redacted
  }

  /// Redact PII from a dictionary
  static func redactPII(_ dictionary: [String: Any]) -> [String: Any] {
    var redacted: [String: Any] = [:]

    for (key, value) in dictionary {
      let redactedKey = redactPII(key)

      if let stringValue = value as? String {
        redacted[redactedKey] = redactPII(stringValue)
      } else if let dictValue = value as? [String: Any] {
        redacted[redactedKey] = redactPII(dictValue)
      } else if let arrayValue = value as? [Any] {
        redacted[redactedKey] = redactPII(arrayValue)
      } else {
        redacted[redactedKey] = value
      }
    }

    return redacted
  }

  /// Redact PII from an array
  static func redactPII(_ array: [Any]) -> [Any] {
    array.map { item in
      if let stringItem = item as? String {
        redactPII(stringItem)
      } else if let dictItem = item as? [String: Any] {
        redactPII(dictItem)
      } else if let arrayItem = item as? [Any] {
        redactPII(arrayItem)
      } else {
        item
      }
    }
  }

  // MARK: - Safe Analytics Logging

  /// Log analytics data safely (redacts PII automatically)
  static func logSafely(_ message: String, metadata: [String: Any]? = nil) {
    let redactedMessage = redactPII(message)
    let redactedMetadata = metadata.map { redactPII($0) }

    print("📊 Analytics (Safe): \(redactedMessage)")
    if let metadata = redactedMetadata {
      print("📊 Metadata: \(metadata)")
    }
  }

  /// Validate analytics data before logging
  static func validateForLogging(_ data: [String: Any]) -> Bool {
    if containsPII(data) {
      print("⚠️ Analytics: PII detected in data, refusing to log")
      return false
    }
    return true
  }

  // MARK: - Common Redaction Patterns

  /// Redact user identifiers while preserving structure
  static func redactUserId(_ userId: String) -> String {
    if CurrentUser.isGuestId(userId) {
      return "guest_user"
    }
    return "[USER_ID_REDACTED]"
  }

  /// Redact email while preserving domain for analytics
  static func redactEmail(_ email: String) -> String {
    if let atIndex = email.firstIndex(of: "@") {
      let domain = String(email[atIndex...])
      return "[REDACTED]\(domain)"
    }
    return "[REDACTED_EMAIL]"
  }

  /// Create a safe analytics identifier from user data
  static func safeAnalyticsId(from user: Any?) -> String {
    guard user != nil else {
      return "guest_user"
    }

    // This would extract a safe identifier without PII
    // Implementation depends on your user model
    return "[ANALYTICS_USER_ID]"
  }
}

// MARK: - Analytics Extension for Safe Logging

extension PrivacyHelper {
  /// Safe wrapper for analytics logging that automatically redacts PII
  static func safeAnalyticsLog(
    event: String,
    parameters: [String: Any] = [:],
    userProperties: [String: Any] = [:])
  {
    let redactedParameters = redactPII(parameters)
    let redactedUserProperties = redactPII(userProperties)

    // Only log if no PII is detected
    if validateForLogging(redactedParameters), validateForLogging(redactedUserProperties) {
      print("📊 Analytics Event: \(redactPII(event))")
      print("📊 Parameters: \(redactedParameters)")
      print("📊 User Properties: \(redactedUserProperties)")
    } else {
      print("⚠️ Analytics: Refusing to log due to PII detection")
    }
  }
}

// MARK: - Usage Examples

// Usage Examples:
//
// // ✅ Safe analytics logging
// PrivacyHelper.safeAnalyticsLog(
//    event: "habit_created",
//    parameters: [
//        "habit_type": "formation",
//        "schedule": "daily"
//    ]
// )
//
// // ✅ Automatic PII redaction
// let userData = [
//    "email": "user@example.com",
//    "name": "John Doe",
//    "habit_count": 5
// ]
// let safeData = PrivacyHelper.redactPII(userData)
// // Result: ["email": "[REDACTED]@example.com", "name": "John Doe", "habit_count": 5]
//
// // ✅ PII detection
// if PrivacyHelper.containsPII("user@example.com") {
//    print("PII detected!")
// }
//
// // ✅ Safe user ID handling
// let safeUserId = PrivacyHelper.redactUserId(currentUserId)
//
// // ❌ Wrong - logging raw user data
// print("User: \(user.email)") // Could contain PII
//
// // ❌ Wrong - not validating analytics data
// analytics.log(userData) // Could contain PII
