import Foundation
import SwiftUI

// MARK: - Migration Service
/// Service that handles data migrations in the background
@MainActor
class MigrationService: ObservableObject {
    static let shared = MigrationService()
    
    // MARK: - Properties
    @Published var isRunning = false
    @Published var lastMigrationDate: Date?
    @Published var migrationStatus: MigrationStatus = .idle
    
    private let migrationManager = DataMigrationManager.shared
    private let userDefaults = UserDefaults.standard
    private let lastMigrationKey = "LastMigrationDate"
    
    private init() {
        loadLastMigrationDate()
    }
    
    // MARK: - Public Methods
    
    /// Check if migration is needed and execute if necessary
    func checkAndExecuteMigrations() async {
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
        isRunning = true
        migrationStatus = .running
        
        do {
            try await migrationManager.executeMigrations()
            migrationStatus = .completed
            lastMigrationDate = Date()
            userDefaults.set(lastMigrationDate, forKey: lastMigrationKey)
            print("✅ MigrationService: Migrations completed successfully")
            
        } catch {
            migrationStatus = .failed(error)
            print("❌ MigrationService: Migration failed: \(error.localizedDescription)")
        }
        
        isRunning = false
    }
    
    /// Get migration history
    func getMigrationHistory() -> [MigrationLogEntry] {
        return migrationManager.getMigrationHistory()
    }
    
    /// Get current migration progress
    func getMigrationProgress() -> Double {
        return migrationManager.migrationProgress
    }
    
    /// Get current migration step
    func getCurrentMigrationStep() -> String {
        return migrationManager.currentMigrationStep
    }
    
    /// Check if app needs to show migration UI
    func shouldShowMigrationUI() -> Bool {
        return migrationStatus == .running || migrationStatus == .failed(nil)
    }
    
    /// Reset migration status
    func resetMigrationStatus() {
        migrationStatus = .idle
    }
    
    // MARK: - Private Methods
    
    private func loadLastMigrationDate() {
        if let date = userDefaults.object(forKey: lastMigrationKey) as? Date {
            lastMigrationDate = date
        }
    }
}

// MARK: - Migration Status
enum MigrationStatus: Equatable {
    case idle
    case running
    case completed
    case failed(Error?)
    
    static func == (lhs: MigrationStatus, rhs: MigrationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.running, .running), (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError?.localizedDescription == rhsError?.localizedDescription
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .idle:
            return "Ready"
        case .running:
            return "Running"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .idle:
            return .gray
        case .running:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - Migration UI Components
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
