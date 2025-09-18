import Foundation
import SwiftUI

// MARK: - Data Error Types
enum DataError: Error, LocalizedError, Identifiable {
    case validation(ValidationError)
    case storage(StorageError)
    case network(NetworkError)
    case persistence(PersistenceError)
    case migration(MigrationError)
    case unknown(Error)
    
    var id: String {
        switch self {
        case .validation(let error):
            return "validation_\(error.id.uuidString)"
        case .storage(let error):
            return "storage_\(error.id.uuidString)"
        case .network(let error):
            return "network_\(error.id.uuidString)"
        case .persistence(let error):
            return "persistence_\(error.id.uuidString)"
        case .migration(let error):
            return "migration_\(error.id.uuidString)"
        case .unknown(let error):
            return "unknown_\(error.localizedDescription.hashValue)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .validation(let error):
            return error.errorDescription
        case .storage(let error):
            return error.errorDescription
        case .network(let error):
            return error.errorDescription
        case .persistence(let error):
            return error.errorDescription
        case .migration(let error):
            return error.errorDescription
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .validation(let error):
            return error.severity == .critical ? .critical : .error
        case .storage(let error):
            return error.severity
        case .network(let error):
            return error.severity
        case .persistence(let error):
            return error.severity
        case .migration(let error):
            return error.severity
        case .unknown:
            return .error
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .validation(let error):
            return getValidationRecoverySuggestion(for: error)
        case .storage(let error):
            return error.recoverySuggestion
        case .network(let error):
            return error.recoverySuggestion
        case .persistence(let error):
            return error.recoverySuggestion
        case .migration(let error):
            return error.recoverySuggestion
        case .unknown:
            return "Please try again. If the problem persists, contact support."
        }
    }
}

// MARK: - Error Severity
enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
}

// MARK: - Storage Error
struct StorageError: Error, LocalizedError, Identifiable {
    let id = UUID()
    let type: StorageErrorType
    let message: String
    let underlyingError: Error?
    let severity: ErrorSeverity
    
    var errorDescription: String? {
        return message
    }
    
    var recoverySuggestion: String? {
        switch type {
        case .fileNotFound:
            return "The data file was not found. The app will create a new one."
        case .permissionDenied:
            return "Please check app permissions in Settings."
        case .diskFull:
            return "Please free up some storage space on your device."
        case .corruptedData:
            return "Data appears to be corrupted. The app will attempt to recover."
        case .quotaExceeded:
            return "You've reached the storage limit. Please delete some old data."
        case .networkUnavailable:
            return "Network is unavailable. Data will be saved locally and synced when available."
        case .authenticationFailed:
            return "Authentication failed. Please sign in again."
        case .syncConflict:
            return "Data conflict detected. The app will resolve this automatically."
        case .unknown:
            return "An unexpected storage error occurred. Please try again."
        }
    }
    
    init(type: StorageErrorType, message: String, underlyingError: Error? = nil, severity: ErrorSeverity = .error) {
        self.type = type
        self.message = message
        self.underlyingError = underlyingError
        self.severity = severity
    }
}

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

// MARK: - Network Error
struct NetworkError: Error, LocalizedError, Identifiable {
    let id = UUID()
    let type: NetworkErrorType
    let message: String
    let underlyingError: Error?
    let severity: ErrorSeverity
    
    var errorDescription: String? {
        return message
    }
    
    var recoverySuggestion: String? {
        switch type {
        case .noConnection:
            return "Please check your internet connection and try again."
        case .timeout:
            return "The request timed out. Please try again."
        case .serverError:
            return "Server is temporarily unavailable. Please try again later."
        case .unauthorized:
            return "Please sign in again to continue."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested resource was not found."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .unknown:
            return "A network error occurred. Please check your connection and try again."
        }
    }
    
    init(type: NetworkErrorType, message: String, underlyingError: Error? = nil, severity: ErrorSeverity = .error) {
        self.type = type
        self.message = message
        self.underlyingError = underlyingError
        self.severity = severity
    }
}

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

// MARK: - Persistence Error
struct PersistenceError: Error, LocalizedError, Identifiable {
    let id = UUID()
    let type: PersistenceErrorType
    let message: String
    let underlyingError: Error?
    let severity: ErrorSeverity
    
    var errorDescription: String? {
        return message
    }
    
    var recoverySuggestion: String? {
        switch type {
        case .saveFailed:
            return "Failed to save data. Please try again."
        case .loadFailed:
            return "Failed to load data. The app will attempt to recover."
        case .deleteFailed:
            return "Failed to delete data. Please try again."
        case .corruptedData:
            return "Data appears to be corrupted. The app will attempt to recover."
        case .migrationFailed:
            return "Data migration failed. Please contact support."
        case .unknown:
            return "A data persistence error occurred. Please try again."
        }
    }
    
    init(type: PersistenceErrorType, message: String, underlyingError: Error? = nil, severity: ErrorSeverity = .error) {
        self.type = type
        self.message = message
        self.underlyingError = underlyingError
        self.severity = severity
    }
}

enum PersistenceErrorType {
    case saveFailed
    case loadFailed
    case deleteFailed
    case corruptedData
    case migrationFailed
    case unknown
}

// MARK: - Migration Error
struct MigrationError: Error, LocalizedError, Identifiable {
    let id = UUID()
    let type: MigrationErrorType
    let message: String
    let underlyingError: Error?
    let severity: ErrorSeverity
    
    var errorDescription: String? {
        return message
    }
    
    var recoverySuggestion: String? {
        switch type {
        case .incompatibleVersion:
            return "Data format is incompatible. Please update the app."
        case .dataLoss:
            return "Some data may be lost during migration. Please backup your data first."
        case .rollbackFailed:
            return "Migration rollback failed. Please contact support."
        case .unknown:
            return "Data migration failed. Please contact support."
        }
    }
    
    init(type: MigrationErrorType, message: String, underlyingError: Error? = nil, severity: ErrorSeverity = .error) {
        self.type = type
        self.message = message
        self.underlyingError = underlyingError
        self.severity = severity
    }
}

enum MigrationErrorType {
    case incompatibleVersion
    case dataLoss
    case rollbackFailed
    case unknown
}

// MARK: - Error Handler
class DataErrorHandler: ObservableObject {
    @Published var currentError: DataError?
    @Published var errorHistory: [DataError] = []
    
    private let maxErrorHistory = 100
    
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
    
    func getErrors(for field: String) -> [DataError] {
        return errorHistory.filter { error in
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
}

// MARK: - Helper Functions
private func getValidationRecoverySuggestion(for error: ValidationError) -> String? {
    switch error.field {
    case "name":
        return "Please enter a valid habit name (2-50 characters)."
    case "description":
        return "Please keep the description under 200 characters."
    case "icon":
        return "Please select a valid icon from the available options."
    case "schedule":
        return "Please select a valid schedule (daily, weekly, monthly, or yearly)."
    case "goal":
        return "Please enter a valid goal number greater than 0."
    case "startDate":
        return "Please select a valid start date."
    case "endDate":
        return "Please select an end date that's after the start date."
    case "baseline":
        return "Please enter a baseline number greater than 0."
    case "target":
        return "Please enter a target number less than the baseline."
    default:
        return "Please check the input and try again."
    }
}

// MARK: - Error Recovery Actions
enum ErrorRecoveryAction {
    case retry
    case ignore
    case abort
    case contactSupport
    case clearData
    case migrateData
}

struct ErrorRecoveryOptions {
    let actions: [ErrorRecoveryAction]
    let defaultAction: ErrorRecoveryAction
    let canRetry: Bool
    let canIgnore: Bool
    let canAbort: Bool
    
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
            case .fileNotFound, .corruptedData:
                self.actions = [.retry, .clearData, .contactSupport]
                self.defaultAction = .retry
                self.canRetry = true
                self.canIgnore = false
                self.canAbort = true
            case .permissionDenied, .diskFull:
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
            
        case .unknown:
            self.actions = [.retry, .contactSupport]
            self.defaultAction = .retry
            self.canRetry = true
            self.canIgnore = false
            self.canAbort = true
        }
    }
}
