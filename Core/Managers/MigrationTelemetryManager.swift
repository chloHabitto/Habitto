import Foundation
import SwiftUI

// MARK: - Migration Telemetry Event
struct MigrationTelemetryEvent: Codable {
    let eventType: String
    let timestamp: Date
    let version: String
    let duration: TimeInterval?
    let errorCode: String?
    let datasetSize: Int?
    let success: Bool
    
    enum CodingKeys: String, CodingKey {
        case eventType, timestamp, version, duration, errorCode, datasetSize, success
    }
}

// MARK: - Kill Switch Manager
@MainActor
class MigrationTelemetryManager: ObservableObject {
    static let shared = MigrationTelemetryManager()
    
    @Published var isMigrationEnabled = true
    @Published var lastTelemetryCheck = Date()
    
    private let userDefaults = UserDefaults.standard
    private let killSwitchURL = URL(string: "https://raw.githubusercontent.com/chloe-lee/Habitto/main/migration-kill-switch.json")!
    private let telemetryKey = "MigrationTelemetryEvents"
    
    private init() {
        // Check kill switch on initialization
        Task {
            await checkKillSwitch()
        }
    }
    
    // MARK: - Kill Switch
    
    func checkKillSwitch() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: killSwitchURL)
            let killSwitchData = try JSONDecoder().decode(KillSwitchData.self, from: data)
            
            isMigrationEnabled = killSwitchData.migrationEnabled
            lastTelemetryCheck = Date()
            
            print("🔧 MigrationTelemetryManager: Kill switch checked - migrations \(isMigrationEnabled ? "enabled" : "disabled")")
            
        } catch {
            print("⚠️ MigrationTelemetryManager: Failed to check kill switch, keeping migrations enabled: \(error)")
            // Fail safe - keep migrations enabled if we can't check
            isMigrationEnabled = true
        }
    }
    
    // MARK: - Telemetry
    
    func recordMigrationStart(version: String, datasetSize: Int) {
        let event = MigrationTelemetryEvent(
            eventType: "migration_start",
            timestamp: Date(),
            version: version,
            duration: nil,
            errorCode: nil,
            datasetSize: datasetSize,
            success: true
        )
        
        recordEvent(event)
    }
    
    func recordMigrationEnd(version: String, duration: TimeInterval, success: Bool, errorCode: String? = nil) {
        let event = MigrationTelemetryEvent(
            eventType: "migration_end",
            timestamp: Date(),
            version: version,
            duration: duration,
            errorCode: errorCode,
            datasetSize: nil,
            success: success
        )
        
        recordEvent(event)
    }
    
    func recordMigrationStep(stepName: String, version: String, success: Bool, errorCode: String? = nil) {
        let event = MigrationTelemetryEvent(
            eventType: "migration_step",
            timestamp: Date(),
            version: version,
            duration: nil,
            errorCode: errorCode,
            datasetSize: nil,
            success: success
        )
        
        recordEvent(event)
    }
    
    private func recordEvent(_ event: MigrationTelemetryEvent) {
        var events = getStoredEvents()
        events.append(event)
        
        // Keep only last 100 events
        if events.count > 100 {
            events = Array(events.suffix(100))
        }
        
        if let data = try? JSONEncoder().encode(events) {
            userDefaults.set(data, forKey: telemetryKey)
        }
        
        print("📊 MigrationTelemetryManager: Recorded \(event.eventType) event")
    }
    
    func getStoredEvents() -> [MigrationTelemetryEvent] {
        guard let data = userDefaults.data(forKey: telemetryKey),
              let events = try? JSONDecoder().decode([MigrationTelemetryEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    func getTelemetrySummary() -> String {
        let events = getStoredEvents()
        let recentEvents = events.filter { $0.timestamp > Date().addingTimeInterval(-86400) } // Last 24 hours
        
        let startEvents = recentEvents.filter { $0.eventType == "migration_start" }
        let endEvents = recentEvents.filter { $0.eventType == "migration_end" }
        let stepEvents = recentEvents.filter { $0.eventType == "migration_step" }
        
        let successRate = endEvents.isEmpty ? 0.0 : Double(endEvents.filter { $0.success }.count) / Double(endEvents.count)
        
        return """
        Migration Telemetry Summary (24h):
        - Total migrations started: \(startEvents.count)
        - Total migrations completed: \(endEvents.count)
        - Success rate: \(String(format: "%.1f", successRate * 100))%
        - Total steps executed: \(stepEvents.count)
        - Failed steps: \(stepEvents.filter { !$0.success }.count)
        """
    }
}

// MARK: - Kill Switch Data
private struct KillSwitchData: Codable {
    let migrationEnabled: Bool
    let reason: String?
    let timestamp: Date
}

// MARK: - Migration Guard
extension DataMigrationManager {
    func checkMigrationSafety() async throws {
        let telemetryManager = MigrationTelemetryManager.shared
        
        // Check kill switch
        await telemetryManager.checkKillSwitch()
        guard telemetryManager.isMigrationEnabled else {
            throw DataMigrationError.migrationDisabledByKillSwitch
        }
        
        // Check for high failure rate in last 24 hours
        let events = telemetryManager.getStoredEvents()
        let recentEvents = events.filter { $0.timestamp > Date().addingTimeInterval(-86400) }
        let failedMigrations = recentEvents.filter { $0.eventType == "migration_end" && !$0.success }
        
        if recentEvents.count >= 5 && Double(failedMigrations.count) / Double(recentEvents.count) > 0.5 {
            throw DataMigrationError.highFailureRateDetected
        }
    }
}

// MARK: - Additional Migration Errors
extension DataMigrationError {
    var errorDescription: String? {
        switch self {
        case .migrationDisabledByKillSwitch:
            return "Migration disabled by remote kill switch"
        case .highFailureRateDetected:
            return "Migration disabled due to high failure rate in last 24 hours"
        case .requiredStepFailed(let step, let error):
            return "Required migration step '\(step)' failed: \(error.localizedDescription)"
        case .invalidRollbackVersion:
            return "Cannot rollback to a version that is not older than current version"
        case .rollbackFailed(let step, let error):
            return "Failed to rollback step '\(step)': \(error.localizedDescription)"
        case .postMigrationValidationFailed(let message):
            return "Post-migration validation failed: \(message)"
        case .unknown:
            return "Unknown migration error"
        }
    }
}
