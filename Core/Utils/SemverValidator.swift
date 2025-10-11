import Foundation

// MARK: - SemverValidator

enum SemverValidator {
  static func isValid(_ version: String) -> Bool {
    // Simple semver validation: major.minor.patch
    let pattern = "^\\d+\\.\\d+\\.\\d+$"
    let regex = try? NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: version.utf16.count)
    return regex?.firstMatch(in: version, options: [], range: range) != nil
  }

  static func compare(_ version1: String, _ version2: String) -> ComparisonResult {
    let components1 = version1.split(separator: ".").compactMap { Int($0) }
    let components2 = version2.split(separator: ".").compactMap { Int($0) }

    // Pad with zeros if needed
    let maxLength = max(components1.count, components2.count)
    let padded1 = components1 + Array(repeating: 0, count: maxLength - components1.count)
    let padded2 = components2 + Array(repeating: 0, count: maxLength - components2.count)

    for (v1, v2) in zip(padded1, padded2) {
      if v1 < v2 { return .orderedAscending }
      if v1 > v2 { return .orderedDescending }
    }

    return .orderedSame
  }

  static func isMonotonic(_ currentVersion: String, previousVersion: String) -> Bool {
    compare(currentVersion, previousVersion) != .orderedAscending
  }
}

// MARK: - Enhanced Storage Invariants with Semver

extension CrashSafeHabitStore {
  func validateStorageInvariantsWithSemver(
    _ container: HabitDataContainer,
    previousVersion: String? = nil) throws
  {
    // 1. Basic invariants
    try validateStorageInvariants(container)

    // 2. Semver validation
    guard SemverValidator.isValid(container.version) else {
      throw HabitStoreError.dataIntegrityError("Invalid semver format: \(container.version)")
    }

    // 3. Monotonicity check
    if let previous = previousVersion {
      guard SemverValidator.isMonotonic(container.version, previousVersion: previous) else {
        throw HabitStoreError
          .dataIntegrityError("Non-monotonic version: \(previous) -> \(container.version)")
      }
    }

    print("✅ CrashSafeHabitStore: Semver validation passed - \(container.version)")
  }
}
