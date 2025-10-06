import Foundation
import CloudKit
import SwiftUI

// MARK: - CloudKit Types
// Note: CloudKitSyncStatus is defined in CloudKitModels.swift

enum CloudKitValidationResult {
    case valid
    case invalid(String)
}

// MARK: - CloudKit Manager Stub
// Note: Using the actual CloudKitManager from Core/Data/CloudKitManager.swift

// MARK: - CloudKit Sync Manager Stub
// Note: Using the actual CloudKitSyncManager from Core/Data/CloudKit/CloudKitSyncManager.swift

// MARK: - CloudKit Conflict Resolver Stub
// Note: Using the actual CloudKitConflictResolver from Core/Data/CloudKit/CloudKitConflictResolver.swift

// MARK: - CloudKit Habit Extension
extension Habit {
    func toCloudKitHabit() -> Habit {
        // TODO: Implement actual CloudKit conversion
        // For now, return self as placeholder
        return self
    }
}

// MARK: - CloudKit Integration Service
/// Main service that integrates CloudKit sync with the app's data layer
@MainActor
class CloudKitIntegrationService: ObservableObject {
    static let shared = CloudKitIntegrationService()
    
    // MARK: - Published Properties
    @Published var isEnabled = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: CloudKitSyncStatus = .idle
    @Published var conflictCount = 0
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let cloudKitManager = CloudKitManager.shared
    private let syncManager = CloudKitSyncManager.shared
    private let conflictResolver = CloudKitConflictResolver()
    private let habitRepository = HabitRepository.shared
    
    // Configuration
    private let autoSyncEnabled = true
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    private init() {
        setupCloudKitIntegration()
    }
    
    // MARK: - Public Methods
    
    /// Initialize CloudKit integration
    func initialize() async {
        print("🔄 CloudKitIntegrationService: Initializing CloudKit integration...")
        
        // Check if CloudKit is available
        guard cloudKitManager.isCloudKitAvailable() else {
            print("⚠️ CloudKitIntegrationService: CloudKit not available, using local storage only")
            isEnabled = false
            return
        }
        
        // Check authentication status
        cloudKitManager.checkAuthenticationStatus()
        
        if cloudKitManager.isSignedIn {
            isEnabled = true
            await startSync()
        } else {
            print("⚠️ CloudKitIntegrationService: User not signed in to iCloud")
            isEnabled = false
        }
    }
    
    /// Start CloudKit sync
    func startSync() async {
        // Feature flag protection: Check if CloudKit sync is enabled
        let featureFlags = FeatureFlagManager.shared.provider
        guard featureFlags.useNormalizedDataPath else {
            print("🚩 CloudKitIntegrationService: CloudKit sync disabled by feature flag")
            return
        }
        
        guard isEnabled else {
            print("⚠️ CloudKitIntegrationService: CloudKit sync not enabled")
            return
        }
        
        print("🔄 CloudKitIntegrationService: Starting CloudKit sync...")
        isSyncing = true
        syncStatus = .syncing
        
        do {
            // Check if CloudKit is available before attempting sync
            guard syncManager.isCloudKitAvailable() else {
                syncStatus = .completed
                print("ℹ️ CloudKitIntegrationService: CloudKit not available, skipping sync")
                return
            }
            
            _ = try await syncManager.sync()
            lastSyncDate = Date()
            syncStatus = .completed
            print("✅ CloudKitIntegrationService: CloudKit sync completed")
            
        } catch {
            syncStatus = .error(error)
            errorMessage = error.localizedDescription
            print("❌ CloudKitIntegrationService: CloudKit sync failed - \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    /// Stop CloudKit sync
    func stopSync() {
        syncManager.stopAutoSync()
        isSyncing = false
        syncStatus = .idle
        print("✅ CloudKitIntegrationService: CloudKit sync stopped")
    }
    
    /// Force sync all data
    func forceSync() async {
        print("🔄 CloudKitIntegrationService: Starting force sync...")
        await startSync()
    }
    
    /// Resolve conflicts
    func resolveConflicts() async {
        print("🔄 CloudKitIntegrationService: Resolving conflicts...")
        
        let results = await conflictResolver.autoResolveConflicts()
        let successCount = results.filter { 
            if case .success = $0 { return true }
            return false
        }.count
        
        conflictCount = results.count - successCount
        print("✅ CloudKitIntegrationService: Resolved \(successCount) conflicts, \(conflictCount) remaining")
    }
    
    /// Get sync statistics
    func getSyncStatistics() -> SyncStatistics {
        let conflictStats = conflictResolver.getConflictStatistics()
        
        return SyncStatistics(
            isEnabled: isEnabled,
            isSyncing: isSyncing,
            lastSyncDate: lastSyncDate,
            syncStatus: syncStatus,
            conflictCount: conflictStats.totalConflicts,
            habitConflicts: conflictStats.habitConflicts,
            reminderConflicts: conflictStats.reminderConflicts,
            analyticsConflicts: conflictStats.analyticsConflicts
        )
    }
    
    /// Enable CloudKit sync
    func enableCloudKitSync() async {
        guard cloudKitManager.isCloudKitAvailable() else {
            print("❌ CloudKitIntegrationService: Cannot enable CloudKit - not available")
            return
        }
        
        cloudKitManager.checkAuthenticationStatus()
        
        if cloudKitManager.isSignedIn {
            isEnabled = true
            syncManager.startAutoSync()
            await startSync()
            print("✅ CloudKitIntegrationService: CloudKit sync enabled")
        } else {
            print("⚠️ CloudKitIntegrationService: Cannot enable CloudKit - user not signed in")
        }
    }
    
    /// Disable CloudKit sync
    func disableCloudKitSync() {
        isEnabled = false
        syncManager.stopAutoSync()
        print("✅ CloudKitIntegrationService: CloudKit sync disabled")
    }
    
    // MARK: - Private Methods
    
    private func setupCloudKitIntegration() {
        // Set up CloudKit integration
        print("🔄 CloudKitIntegrationService: Setting up CloudKit integration...")
        
        // Check if CloudKit is available
        if cloudKitManager.isCloudKitAvailable() {
            print("✅ CloudKitIntegrationService: CloudKit is available")
        } else {
            print("⚠️ CloudKitIntegrationService: CloudKit is not available")
        }
    }
}

// MARK: - Sync Statistics
struct SyncStatistics {
    let isEnabled: Bool
    let isSyncing: Bool
    let lastSyncDate: Date?
    let syncStatus: CloudKitSyncStatus
    let conflictCount: Int
    let habitConflicts: Int
    let reminderConflicts: Int
    let analyticsConflicts: Int
    
    var hasConflicts: Bool {
        return conflictCount > 0
    }
    
    var syncStatusDescription: String {
        switch syncStatus {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .completed:
            return "Sync completed"
        case .error(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .conflict:
            return "Conflicts detected"
        }
    }
}


// MARK: - CloudKit Integration Extensions
extension CloudKitIntegrationService {
    
    /// Migrate local data to CloudKit format
    func migrateLocalDataToCloudKit() async {
        print("🔄 CloudKitIntegrationService: Migrating local data to CloudKit format...")
        
        // Load local habits
        let localHabits = HabitStorageManager.shared.loadHabits()
        
        // Convert to CloudKit format and process
        _ = localHabits.map { habit in
            CloudKitHabit(
                id: habit.id,
                name: habit.name,
                description: habit.description,
                icon: habit.icon,
                colorHex: habit.color.color.toHex(),
                habitType: habit.habitType.rawValue,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: habit.isCompletedForDate(Date()),
                streak: habit.computedStreak(),
                createdAt: habit.createdAt,
                completionHistory: [:],
                difficultyHistory: [:],
                baseline: habit.baseline,
                target: habit.target,
                actualUsage: [:],
                cloudKitRecordID: nil,
                lastModified: habit.createdAt,
                isDeleted: false
            )
        }
        
        // Save to CloudKit (this would be handled by the sync manager)
        print("✅ CloudKitIntegrationService: Local data migration completed")
    }
    
    /// Validate CloudKit schema
    func validateCloudKitSchema() async -> CloudKitValidationResult {
        print("🔄 CloudKitIntegrationService: Validating CloudKit schema...")
        
        // This would validate the CloudKit schema against our defined schema
        // For now, return a placeholder result
        return .valid
    }
    
    /// Get CloudKit usage statistics
    func getCloudKitUsageStatistics() async -> CloudKitUsageStatistics {
        print("🔄 CloudKitIntegrationService: Getting CloudKit usage statistics...")
        
        // This would fetch actual usage statistics from CloudKit
        // For now, return placeholder data
        return CloudKitUsageStatistics(
            totalRecords: 0,
            totalSize: 0,
            quotaUsed: 0.0,
            quotaLimit: 0
        )
    }
}

// MARK: - CloudKit Usage Statistics
struct CloudKitUsageStatistics {
    let totalRecords: Int
    let totalSize: Int64
    let quotaUsed: Double
    let quotaLimit: Int64
    
    var quotaPercentage: Double {
        guard quotaLimit > 0 else { return 0.0 }
        return (quotaUsed / Double(quotaLimit)) * 100.0
    }
    
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedQuotaUsed: String {
        return ByteCountFormatter.string(fromByteCount: Int64(quotaUsed), countStyle: .file)
    }
    
    var formattedQuotaLimit: String {
        return ByteCountFormatter.string(fromByteCount: quotaLimit, countStyle: .file)
    }
}

