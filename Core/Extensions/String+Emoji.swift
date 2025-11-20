import Foundation

// MARK: - Character Emoji Extensions

extension Character {
  /// Checks if a character is an emoji
  /// This properly handles simple emojis, emoji sequences (ZWJ), flags, and combining characters
  var isEmoji: Bool {
    // Check if the character has any emoji scalars
    let hasEmojiScalar = unicodeScalars.contains { scalar in
      scalar.properties.isEmoji || scalar.properties.isEmojiPresentation
    }
    
    guard hasEmojiScalar else { return false }
    
    // For emoji sequences (like flags, ZWJ sequences, skin tones), we need to check
    // that non-emoji scalars are only allowed combining/modifying characters
    let allowedNonEmojiScalars: Set<UnicodeScalar> = [
      "\u{200D}", // ZWJ (Zero Width Joiner) - used in emoji sequences
      "\u{FE0F}", // Variation Selector-16 - forces emoji presentation
      "\u{FE0E}", // Variation Selector-15 - forces text presentation (rare in emoji sequences)
    ]
    
    // Check that all scalars are either emoji OR allowed combining characters
    return unicodeScalars.allSatisfy { scalar in
      scalar.properties.isEmoji ||
      scalar.properties.isEmojiPresentation ||
      allowedNonEmojiScalars.contains(scalar) ||
      // Allow regional indicator symbols (used in flags like 🇺🇸)
      (scalar.value >= 0x1F1E6 && scalar.value <= 0x1F1FF) ||
      // Allow Fitzpatrick skin tone modifiers (U+1F3FB to U+1F3FF)
      (scalar.value >= 0x1F3FB && scalar.value <= 0x1F3FF) ||
      // Allow combining characters that might be part of emoji sequences
      scalar.properties.generalCategory == .nonspacingMark ||
      scalar.properties.generalCategory == .enclosingMark
    }
  }
}

// MARK: - String Emoji Extensions

extension String {
  /// Checks if the string contains only emoji characters
  /// This properly handles simple emojis, emoji sequences, flags, and skin tone modifiers
  var containsOnlyEmoji: Bool {
    // Allow empty string
    if isEmpty { return true }

    // Check each character (grapheme cluster) individually
    for char in self {
      if !char.isEmoji {
        return false
      }
    }
    return true
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
      if char.isEmoji {
        result.append(char)
        taken += 1
        if taken >= count { break }
      }
    }

    return result
  }
}
