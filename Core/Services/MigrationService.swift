import Foundation
import SwiftUI

// MARK: - MigrationService

/// Service that handles data migrations in the background
@MainActor
class MigrationService: ObservableObject {
  // MARK: Lifecycle

  private init() {
    loadLastMigrationDate()
  }

  // MARK: Internal

  static let shared = MigrationService()

  @Published var isRunning = false
  @Published var lastMigrationDate: Date?
  @Published var migrationStatus: MigrationStatus = .pending

  // MARK: - Public Methods

  /// Check if migration is needed and execute if necessary
  func checkAndExecuteMigrations() async {
    // Skip migration operations during vacation mode
    if VacationManager.shared.isActive {
      print("⚠️ MigrationService: Skipping migrations during vacation mode")
      return
    }

    guard !isRunning else {
      print("⚠️ MigrationService: Migration already in progress")
      return
    }

    guard migrationManager.needsMigration() else {
      print("✅ MigrationService: No migrations needed")
      return
    }

    await executeMigrations()
  }

  /// Execute migrations manually
  func executeMigrations() async {
    // Skip migration operations during vacation mode
    if VacationManager.shared.isActive {
      print("⚠️ MigrationService: Skipping manual migrations during vacation mode")
      return
    }

    isRunning = true
    migrationStatus = .inProgress

    do {
      try await migrationManager.executeMigrations()
      migrationStatus = .completed
      lastMigrationDate = Date()
      userDefaults.set(lastMigrationDate, forKey: lastMigrationKey)
      print("✅ MigrationService: Migrations completed successfully")

    } catch {
      migrationStatus = .failed
      print("❌ MigrationService: Migration failed: \(error.localizedDescription)")
    }

    isRunning = false
  }

  /// Get migration history
  func getMigrationHistory() -> [MigrationLogEntry] {
    migrationManager.getMigrationHistory()
  }

  /// Get current migration progress
  func getMigrationProgress() -> Double {
    migrationManager.migrationProgress
  }

  /// Get current migration step
  func getCurrentMigrationStep() -> String {
    migrationManager.currentMigrationStep
  }

  /// Check if app needs to show migration UI
  func shouldShowMigrationUI() -> Bool {
    migrationStatus == .inProgress || migrationStatus == .failed
  }

  /// Reset migration status
  func resetMigrationStatus() {
    migrationStatus = .pending
  }

  // MARK: Private

  private let migrationManager = DataMigrationManager.shared
  private let userDefaults = UserDefaults.standard
  private let lastMigrationKey = "LastMigrationDate"

  // MARK: - Private Methods

  private func loadLastMigrationDate() {
    if let date = userDefaults.object(forKey: lastMigrationKey) as? Date {
      lastMigrationDate = date
    }
  }
}

// MARK: - MigrationServiceStatus

enum MigrationServiceStatus: Equatable {
  case idle
  case running
  case completed
  case failed(Error?)

  // MARK: Internal

  var displayName: String {
    switch self {
    case .idle:
      "Ready"
    case .running:
      "Running"
    case .completed:
      "Completed"
    case .failed:
      "Failed"
    }
  }

  var color: Color {
    switch self {
    case .idle:
      .gray
    case .running:
      .blue
    case .completed:
      .green
    case .failed:
      .red
    }
  }

  static func == (lhs: MigrationServiceStatus, rhs: MigrationServiceStatus) -> Bool {
    switch (lhs, rhs) {
    case (.completed, .completed),
         (.idle, .idle),
         (.running, .running):
      true
    case (.failed(let lhsError), .failed(let rhsError)):
      lhsError?.localizedDescription == rhsError?.localizedDescription
    default:
      false
    }
  }
}

// MARK: - MigrationProgressView

struct MigrationProgressView: View {
  @ObservedObject var migrationService = MigrationService.shared
  @ObservedObject var migrationManager = DataMigrationManager.shared

  var body: some View {
    VStack(spacing: 20) {
      // Header
      VStack(spacing: 8) {
        Image(systemName: "arrow.triangle.2.circlepath")
          .font(.system(size: 40))
          .foregroundColor(.blue)

        Text("Updating Your Data")
          .font(.title2)
          .fontWeight(.semibold)

        Text("We're improving your habit tracking experience")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      // Progress
      VStack(spacing: 12) {
        ProgressView(value: migrationManager.migrationProgress)
          .progressViewStyle(LinearProgressViewStyle())
          .scaleEffect(x: 1, y: 2, anchor: .center)

        Text(migrationManager.currentMigrationStep)
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      // Status
      HStack {
        Circle()
          .fill(migrationService.migrationStatus.color)
          .frame(width: 8, height: 8)

        Text(migrationService.migrationStatus.displayName)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(24)
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .shadow(radius: 8)
  }
}

// MARK: - MigrationErrorView

struct MigrationErrorView: View {
  let error: Error
  let onRetry: () -> Void
  let onSkip: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      // Error Icon
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 40))
        .foregroundColor(.red)

      // Error Message
      VStack(spacing: 8) {
        Text("Migration Failed")
          .font(.title2)
          .fontWeight(.semibold)

        Text(error.localizedDescription)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      // Actions
      VStack(spacing: 12) {
        Button("Try Again") {
          onRetry()
        }
        .buttonStyle(.borderedProminent)

        Button("Skip for Now") {
          onSkip()
        }
        .buttonStyle(.bordered)
      }
    }
    .padding(24)
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .shadow(radius: 8)
  }
}
