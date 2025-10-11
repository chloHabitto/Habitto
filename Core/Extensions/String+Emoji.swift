import Foundation

// MARK: - String Emoji Extensions

extension String {
  /// Checks if the string contains only emoji characters
  var containsOnlyEmoji: Bool {
    // Allow empty string
    if isEmpty { return true }

    // Check if all unicode scalars are emoji or emoji presentation
    return unicodeScalars.allSatisfy { scalar in
      scalar.properties.isEmoji || scalar.properties.isEmojiPresentation
    }
  }

  /// Returns true if the string is a single emoji character
  var isSingleEmoji: Bool {
    count == 1 && containsOnlyEmoji
  }

  /// Returns the first N emoji characters from the string
  func emojisPrefix(_ count: Int) -> String {
    var taken = 0
    var result = ""

    for char in self {
      if String(char).containsOnlyEmoji {
        result.append(char)
        taken += 1
        if taken >= count { break }
      }
    }

    return result
  }
}
