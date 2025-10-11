import Foundation
import SwiftUI

// MARK: - DataError

enum DataError: Error, LocalizedError, Identifiable {
  case validation(ValidationError)
  case storage(StorageError)
  case network(NetworkError)
  case persistence(PersistenceError)
  case migration(MigrationError)
  case featureDisabled(String)
  case unknown(Error)

  // MARK: Internal

  var id: String {
    switch self {
    case .validation(let error):
      "validation_\(error.id.uuidString)"
    case .storage(let error):
      "storage_\(error.id.uuidString)"
    case .network(let error):
      "network_\(error.id.uuidString)"
    case .persistence(let error):
      "persistence_\(error.id.uuidString)"
    case .migration(let error):
      "migration_\(error.id.uuidString)"
    case .featureDisabled(let message):
      "feature_disabled_\(message.hashValue)"
    case .unknown(let error):
      "unknown_\(error.localizedDescription.hashValue)"
    }
  }

  var errorDescription: String? {
    switch self {
    case .validation(let error):
      error.errorDescription
    case .storage(let error):
      error.errorDescription
    case .network(let error):
      error.errorDescription
    case .persistence(let error):
      error.errorDescription
    case .migration(let error):
      error.errorDescription
    case .featureDisabled(let message):
      "Feature disabled: \(message)"
    case .unknown(let error):
      "An unexpected error occurred: \(error.localizedDescription)"
    }
  }

  var severity: ErrorSeverity {
    switch self {
    case .validation(let error):
      error.severity == .critical ? .critical : .error
    case .storage(let error):
      error.severity
    case .network(let error):
      error.severity
    case .persistence(let error):
      error.severity
    case .migration(let error):
      error.severity
    case .featureDisabled:
      .warning
    case .unknown:
      .error
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .validation(let error):
      getValidationRecoverySuggestion(for: error)
    case .storage(let error):
      error.recoverySuggestion
    case .network(let error):
      error.recoverySuggestion
    case .persistence(let error):
      error.recoverySuggestion
    case .migration(let error):
      error.recoverySuggestion
    case .featureDisabled:
      "This feature is currently disabled. Please contact support if you believe this is an error."
    case .unknown:
      "Please try again. If the problem persists, contact support."
    }
  }
}

// MARK: - ErrorSeverity

enum ErrorSeverity {
  case info
  case warning
  case error
  case critical
}

// MARK: - StorageError

struct StorageError: Error, LocalizedError, Identifiable {
  // MARK: Lifecycle

  init(
    type: StorageErrorType,
    message: String,
    underlyingError: Error? = nil,
    severity: ErrorSeverity = .error)
  {
    self.type = type
    self.message = message
    self.underlyingError = underlyingError
    self.severity = severity
  }

  // MARK: Internal

  let id = UUID()
  let type: StorageErrorType
  let message: String
  let underlyingError: Error?
  let severity: ErrorSeverity

  var errorDescription: String? {
    message
  }

  var recoverySuggestion: String? {
    switch type {
    case .fileNotFound:
      "The data file was not found. The app will create a new one."
    case .permissionDenied:
      "Please check app permissions in Settings."
    case .diskFull:
      "Please free up some storage space on your device."
    case .corruptedData:
      "Data appears to be corrupted. The app will attempt to recover."
    case .quotaExceeded:
      "You've reached the storage limit. Please delete some old data."
    case .networkUnavailable:
      "Network is unavailable. Data will be saved locally and synced when available."
    case .authenticationFailed:
      "Authentication failed. Please sign in again."
    case .syncConflict:
      "Data conflict detected. The app will resolve this automatically."
    case .unknown:
      "An unexpected storage error occurred. Please try again."
    }
  }
}

// MARK: - StorageErrorType

enum StorageErrorType {
  case fileNotFound
  case permissionDenied
  case diskFull
  case corruptedData
  case quotaExceeded
  case networkUnavailable
  case authenticationFailed
  case syncConflict
  case unknown
}

// MARK: - NetworkError

struct NetworkError: Error, LocalizedError, Identifiable {
  // MARK: Lifecycle

  init(
    type: NetworkErrorType,
    message: String,
    underlyingError: Error? = nil,
    severity: ErrorSeverity = .error)
  {
    self.type = type
    self.message = message
    self.underlyingError = underlyingError
    self.severity = severity
  }

  // MARK: Internal

  let id = UUID()
  let type: NetworkErrorType
  let message: String
  let underlyingError: Error?
  let severity: ErrorSeverity

  var errorDescription: String? {
    message
  }

  var recoverySuggestion: String? {
    switch type {
    case .noConnection:
      "Please check your internet connection and try again."
    case .timeout:
      "The request timed out. Please try again."
    case .serverError:
      "Server is temporarily unavailable. Please try again later."
    case .unauthorized:
      "Please sign in again to continue."
    case .forbidden:
      "You don't have permission to perform this action."
    case .notFound:
      "The requested resource was not found."
    case .rateLimited:
      "Too many requests. Please wait a moment and try again."
    case .unknown:
      "A network error occurred. Please check your connection and try again."
    }
  }
}

// MARK: - NetworkErrorType

enum NetworkErrorType {
  case noConnection
  case timeout
  case serverError
  case unauthorized
  case forbidden
  case notFound
  case rateLimited
  case unknown
}

// MARK: - PersistenceError

struct PersistenceError: Error, LocalizedError, Identifiable {
  // MARK: Lifecycle

  init(
    type: PersistenceErrorType,
    message: String,
    underlyingError: Error? = nil,
    severity: ErrorSeverity = .error)
  {
    self.type = type
    self.message = message
    self.underlyingError = underlyingError
    self.severity = severity
  }

  // MARK: Internal

  let id = UUID()
  let type: PersistenceErrorType
  let message: String
  let underlyingError: Error?
  let severity: ErrorSeverity

  var errorDescription: String? {
    message
  }

  var recoverySuggestion: String? {
    switch type {
    case .saveFailed:
      "Failed to save data. Please try again."
    case .loadFailed:
      "Failed to load data. The app will attempt to recover."
    case .deleteFailed:
      "Failed to delete data. Please try again."
    case .corruptedData:
      "Data appears to be corrupted. The app will attempt to recover."
    case .migrationFailed:
      "Data migration failed. Please contact support."
    case .unknown:
      "A data persistence error occurred. Please try again."
    }
  }
}

// MARK: - PersistenceErrorType

enum PersistenceErrorType {
  case saveFailed
  case loadFailed
  case deleteFailed
  case corruptedData
  case migrationFailed
  case unknown
}

// MARK: - MigrationError

struct MigrationError: Error, LocalizedError, Identifiable {
  // MARK: Lifecycle

  init(
    type: MigrationErrorType,
    message: String,
    underlyingError: Error? = nil,
    severity: ErrorSeverity = .error)
  {
    self.type = type
    self.message = message
    self.underlyingError = underlyingError
    self.severity = severity
  }

  // MARK: Internal

  let id = UUID()
  let type: MigrationErrorType
  let message: String
  let underlyingError: Error?
  let severity: ErrorSeverity

  var errorDescription: String? {
    message
  }

  var recoverySuggestion: String? {
    switch type {
    case .incompatibleVersion:
      "Data format is incompatible. Please update the app."
    case .dataLoss:
      "Some data may be lost during migration. Please backup your data first."
    case .rollbackFailed:
      "Migration rollback failed. Please contact support."
    case .unknown:
      "Data migration failed. Please contact support."
    }
  }
}

// MARK: - MigrationErrorType

enum MigrationErrorType {
  case incompatibleVersion
  case dataLoss
  case rollbackFailed
  case unknown
}

// MARK: - DataErrorHandler

class DataErrorHandler: ObservableObject {
  // MARK: Internal

  @Published var currentError: DataError?
  @Published var errorHistory: [DataError] = []

  func handle(_ error: DataError) {
    DispatchQueue.main.async {
      self.currentError = error
      self.addToHistory(error)
      self.logError(error)
    }
  }

  func clearCurrentError() {
    DispatchQueue.main.async {
      self.currentError = nil
    }
  }

  func getErrors(for field: String) -> [DataError] {
    errorHistory.filter { error in
      if case .validation(let validationError) = error {
        return validationError.field == field
      }
      return false
    }
  }

  func clearErrors(for field: String) {
    errorHistory.removeAll { error in
      if case .validation(let validationError) = error {
        return validationError.field == field
      }
      return false
    }
  }

  // MARK: Private

  private let maxErrorHistory = 100

  private func addToHistory(_ error: DataError) {
    errorHistory.insert(error, at: 0)
    if errorHistory.count > maxErrorHistory {
      errorHistory = Array(errorHistory.prefix(maxErrorHistory))
    }
  }

  private func logError(_ error: DataError) {
    let severity = error.severity
    let message = error.errorDescription ?? "Unknown error"

    switch severity {
    case .info:
      print("ℹ️ DataError: \(message)")
    case .warning:
      print("⚠️ DataError: \(message)")
    case .error:
      print("❌ DataError: \(message)")
    case .critical:
      print("🚨 DataError: \(message)")
    }

    // In a real app, you might want to send critical errors to a crash reporting service
    if severity == .critical {
      // Send to crash reporting service
      // CrashReportingService.recordError(error)
    }
  }
}

// MARK: - Helper Functions

private func getValidationRecoverySuggestion(for error: ValidationError) -> String? {
  switch error.field {
  case "name":
    "Please enter a valid habit name (2-50 characters)."
  case "description":
    "Please keep the description under 200 characters."
  case "icon":
    "Please select a valid icon from the available options."
  case "schedule":
    "Please select a valid schedule (daily, weekly, monthly, or yearly)."
  case "goal":
    "Please enter a valid goal number greater than 0."
  case "startDate":
    "Please select a valid start date."
  case "endDate":
    "Please select an end date that's after the start date."
  case "baseline":
    "Please enter a baseline number greater than 0."
  case "target":
    "Please enter a target number less than the baseline."
  default:
    "Please check the input and try again."
  }
}

// MARK: - ErrorRecoveryAction

enum ErrorRecoveryAction {
  case retry
  case ignore
  case abort
  case contactSupport
  case clearData
  case migrateData
}

// MARK: - ErrorRecoveryOptions

struct ErrorRecoveryOptions {
  // MARK: Lifecycle

  init(for error: DataError) {
    switch error {
    case .validation:
      self.actions = [.retry, .ignore]
      self.defaultAction = .retry
      self.canRetry = true
      self.canIgnore = true
      self.canAbort = false

    case .storage(let storageError):
      switch storageError.type {
      case .corruptedData,
           .fileNotFound:
        self.actions = [.retry, .clearData, .contactSupport]
        self.defaultAction = .retry
        self.canRetry = true
        self.canIgnore = false
        self.canAbort = true

      case .diskFull,
           .permissionDenied:
        self.actions = [.retry, .contactSupport]
        self.defaultAction = .retry
        self.canRetry = true
        self.canIgnore = false
        self.canAbort = true

      default:
        self.actions = [.retry, .ignore, .contactSupport]
        self.defaultAction = .retry
        self.canRetry = true
        self.canIgnore = true
        self.canAbort = true
      }

    case .network:
      self.actions = [.retry, .ignore]
      self.defaultAction = .retry
      self.canRetry = true
      self.canIgnore = true
      self.canAbort = false

    case .persistence:
      self.actions = [.retry, .contactSupport]
      self.defaultAction = .retry
      self.canRetry = true
      self.canIgnore = false
      self.canAbort = true

    case .migration:
      self.actions = [.migrateData, .contactSupport, .abort]
      self.defaultAction = .migrateData
      self.canRetry = false
      self.canIgnore = false
      self.canAbort = true

    case .featureDisabled:
      self.actions = [.contactSupport]
      self.defaultAction = .contactSupport
      self.canRetry = false
      self.canIgnore = false
      self.canAbort = false

    case .unknown:
      self.actions = [.retry, .contactSupport]
      self.defaultAction = .retry
      self.canRetry = true
      self.canIgnore = false
      self.canAbort = true
    }
  }

  // MARK: Internal

  let actions: [ErrorRecoveryAction]
  let defaultAction: ErrorRecoveryAction
  let canRetry: Bool
  let canIgnore: Bool
  let canAbort: Bool
}
