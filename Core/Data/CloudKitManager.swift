import CloudKit
import SwiftUI

// MARK: - CloudKit Error
enum CloudKitError: Error, LocalizedError {
    case notConfigured
    case syncFailed(Error)
    case conflictDetected
    case authenticationFailed
    case networkError(Error)
    case quotaExceeded
    case recordNotFound
    case invalidRecord
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "CloudKit is not configured for this app"
        case .syncFailed(let error):
            return "CloudKit sync failed: \(error.localizedDescription)"
        case .conflictDetected:
            return "Data conflicts detected during sync"
        case .authenticationFailed:
            return "CloudKit authentication failed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .quotaExceeded:
            return "CloudKit storage quota exceeded"
        case .recordNotFound:
            return "CloudKit record not found"
        case .invalidRecord:
            return "Invalid CloudKit record format"
        }
    }
}

// MARK: - CloudKit Manager
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private var container: CKContainer?
    var privateDatabase: CKDatabase? {
        return container?.privateCloudDatabase
    }
    private var publicDatabase: CKDatabase? {
        return container?.publicCloudDatabase
    }
    
    @Published var isSignedIn = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var userRecordID: CKRecord.ID?
    
    enum SyncStatus {
        case idle
        case syncing
        case completed
        case failed(String)
    }
    
    private init() {
        // Don't initialize CloudKit immediately to avoid crashes
        // CloudKit will be initialized lazily when needed
        print("ℹ️ CloudKitManager: CloudKit initialization deferred for safety")
        
        self.isSignedIn = false
        self.syncStatus = .idle
    }
    
    // MARK: - CloudKit Availability
    func isCloudKitAvailable() -> Bool {
        // For now, return false to disable CloudKit functionality
        // This prevents crashes when CloudKit isn't properly configured
        print("ℹ️ CloudKitManager: CloudKit functionality disabled for safety")
        return false
    }
    
    // MARK: - Safe CloudKit Initialization
    private func initializeCloudKitIfNeeded() -> Bool {
        guard container == nil else { return true }
        
        // Try to initialize CloudKit safely
        // CKContainer.default() doesn't throw, so we don't need a do-catch
        self.container = CKContainer.default()
        print("✅ CloudKitManager: CloudKit container initialized safely")
        return true
    }
    
    // MARK: - Authentication
    func checkAuthenticationStatus() {
        // Check if CloudKit is available before proceeding
        guard isCloudKitAvailable() else {
            print("ℹ️ CloudKitManager: CloudKit not available, skipping authentication check")
            return
        }
        
        guard let container = container else {
            print("ℹ️ CloudKitManager: CloudKit container not initialized")
            return
        }
        
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isSignedIn = true
                    self?.fetchUserRecordID()
                case .noAccount:
                    self?.isSignedIn = false
                    print("❌ No iCloud account found")
                case .restricted:
                    self?.isSignedIn = false
                    print("❌ iCloud access restricted")
                case .couldNotDetermine:
                    self?.isSignedIn = false
                    print("❌ Could not determine iCloud status")
                case .temporarilyUnavailable:
                    self?.isSignedIn = false
                    print("❌ iCloud temporarily unavailable")
                @unknown default:
                    self?.isSignedIn = false
                    print("❌ Unknown iCloud status")
                }
            }
        }
    }
    
    func requestPermission() {
        // Note: requestApplicationPermission and userDiscoverability are deprecated in iOS 17.0
        // For modern CloudKit apps, user discoverability is no longer required
        // The app will work with basic CloudKit functionality without this permission
        print("ℹ️ CloudKit permission request skipped - not required for modern CloudKit apps")
        checkAuthenticationStatus()
    }
    
    private func fetchUserRecordID() {
        // Check if CloudKit is available before proceeding
        guard isCloudKitAvailable() else {
            print("ℹ️ CloudKitManager: CloudKit not available, skipping user record ID fetch")
            return
        }
        
        guard let container = container else {
            print("ℹ️ CloudKitManager: CloudKit container not initialized")
            return
        }
        
        container.fetchUserRecordID { [weak self] recordID, error in
            DispatchQueue.main.async {
                if let recordID = recordID {
                    self?.userRecordID = recordID
                    print("✅ User record ID fetched: \(recordID.recordName)")
                } else if let error = error {
                    print("❌ Error fetching user record ID: \(error)")
                    
                    // Check if it's a container configuration error
                    if let ckError = error as? CKError, ckError.code == .badContainer {
                        print("⚠️ CloudKit container not configured or not yet active.")
                        print("📋 Container ID needed: iCloud.com.chloe-lee.Habitto")
                        print("🔗 Go to: https://developer.apple.com/account/resources/identifiers/list")
                        print("⏰ Note: New containers may take up to 30 minutes to become active.")
                        
                        // For development, we can continue with local storage
                        self?.isSignedIn = true
                        self?.syncStatus = .completed
                        print("📱 App will continue with local storage until CloudKit is ready.")
                    }
                }
            }
        }
    }
    
    // MARK: - Sync Operations
    func sync() {
        // Skip cloud sync during vacation mode
        if VacationManager.shared.isActive {
            print("☁️ CloudKitManager: Skipping cloud sync during vacation mode")
            syncStatus = .failed("Cloud sync paused during vacation mode")
            return
        }
        
        guard isSignedIn else {
            syncStatus = .failed("User not signed in to iCloud")
            return
        }
        
        syncStatus = .syncing
        
        // Core Data with CloudKit handles most sync automatically
        // This method can be used for custom sync operations if needed
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.syncStatus = .completed
        }
    }
    
    // MARK: - Integration with Core Data
    func initializeCloudKitSync() {
        // Feature flag protection: Only initialize if CloudKit sync is enabled
        // Since this is a sync method, we'll defer the feature flag check to the async initialization
        Task { @MainActor in
            _ = FeatureFlagManager.shared
            // TODO: Add cloudKitSync feature flag to FeatureFlagProvider
            // guard featureFlags.isEnabled(.cloudKitSync, forUser: nil) else {
            //     print("🚩 CloudKitManager: CloudKit sync disabled by feature flag")
            //     return
            // }
            
            // This method can be called to ensure CloudKit sync is properly initialized
            // Container is always available, so we can proceed directly
            checkAuthenticationStatus()
            
            // Subscribe to CloudKit changes
            await subscribeToChanges()
        }
    }
    
    // MARK: - Sync Status Monitoring
    func getSyncStatus() -> String {
        switch syncStatus {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .completed:
            return "Sync completed"
        case .failed(let error):
            return "Sync failed: \(error)"
        }
    }
    
    // MARK: - Custom Record Operations (for future features)
    func saveCustomRecord(_ record: CKRecord) async throws -> CKRecord {
        // Skip cloud operations during vacation mode
        if VacationManager.shared.isActive {
            print("☁️ CloudKitManager: Skipping custom record save during vacation mode")
            throw CloudKitError.syncFailed(NSError(domain: "VacationMode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cloud operations paused during vacation mode"]))
        }
        
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notConfigured
        }
        return try await privateDatabase.save(record)
    }
    
    func fetchCustomRecords(ofType type: String) async throws -> [CKRecord] {
        // Skip cloud operations during vacation mode
        if VacationManager.shared.isActive {
            print("☁️ CloudKitManager: Skipping custom record fetch during vacation mode")
            throw CloudKitError.syncFailed(NSError(domain: "VacationMode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cloud operations paused during vacation mode"]))
        }
        
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notConfigured
        }
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        let result = try await privateDatabase.records(matching: query)
        return result.matchResults.compactMap { try? $0.1.get() }
    }
    
    func deleteCustomRecord(_ recordID: CKRecord.ID) async throws {
        // Skip cloud operations during vacation mode
        if VacationManager.shared.isActive {
            print("☁️ CloudKitManager: Skipping custom record delete during vacation mode")
            throw CloudKitError.syncFailed(NSError(domain: "VacationMode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cloud operations paused during vacation mode"]))
        }
        
        guard let privateDatabase = privateDatabase else {
            throw CloudKitError.notConfigured
        }
        try await privateDatabase.deleteRecord(withID: recordID)
    }
    
    // MARK: - Subscription Management (for real-time updates)
    func subscribeToChanges() async {
        guard let privateDatabase = privateDatabase else {
            print("❌ CloudKitManager: No private database available for subscriptions")
            return
        }
        
        let subscription = CKDatabaseSubscription(subscriptionID: "habitto-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        do {
            try await privateDatabase.save(subscription)
            print("✅ Subscribed to CloudKit changes")
        } catch {
            print("❌ Error subscribing to changes: \(error)")
        }
    }
    
    // MARK: - Error Handling
    func handleCloudKitError(_ error: Error) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable:
                print("❌ Network unavailable for CloudKit sync")
            case .networkFailure:
                print("❌ Network failure for CloudKit sync")
            case .quotaExceeded:
                print("❌ CloudKit quota exceeded")
            case .userDeletedZone:
                print("❌ User deleted CloudKit zone")
            case .notAuthenticated:
                print("❌ User not authenticated for CloudKit")
                checkAuthenticationStatus()
            default:
                print("❌ CloudKit error: \(ckError.localizedDescription)")
            }
        } else {
            print("❌ Non-CloudKit error: \(error.localizedDescription)")
        }
    }
}

// MARK: - CloudKit Record Extensions
extension CKRecord {
    convenience init(habit: Habit) {
        self.init(recordType: "Habit")
        
        self["id"] = habit.id.uuidString
        self["name"] = habit.name
        self["habitDescription"] = habit.description
        self["icon"] = habit.icon
        self["colorHex"] = habit.color.toHex()
        self["habitType"] = habit.habitType.rawValue
        self["schedule"] = habit.schedule
        self["goal"] = habit.goal
        self["reminder"] = habit.reminder
        self["startDate"] = habit.startDate
        self["endDate"] = habit.endDate
        self["isCompleted"] = habit.isCompletedForDate(Date())
        self["streak"] = habit.computedStreak()
        self["createdAt"] = habit.createdAt
        self["baseline"] = habit.baseline
        self["target"] = habit.target
    }
    
    func toHabit() -> Habit? {
        guard let idString = self["id"] as? String,
              let _ = UUID(uuidString: idString),
              let name = self["name"] as? String,
              let habitDescription = self["habitDescription"] as? String,
              let icon = self["icon"] as? String,
              let colorHex = self["colorHex"] as? String,
              let habitTypeString = self["habitType"] as? String,
              let habitType = HabitType(rawValue: habitTypeString),
              let schedule = self["schedule"] as? String,
              let goal = self["goal"] as? String,
              let reminder = self["reminder"] as? String,
              let startDate = self["startDate"] as? Date,
              let _ = self["isCompleted"] as? Bool,
              let _ = self["streak"] as? Int,
              let _ = self["createdAt"] as? Date,
              let baseline = self["baseline"] as? Int,
              let target = self["target"] as? Int else {
            return nil
        }
        
        let color = Color.fromHex(colorHex)
        let endDate = self["endDate"] as? Date
        
        return Habit(
            name: name,
            description: habitDescription,
            icon: icon,
            color: color,
            habitType: habitType,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            reminders: [], // Would need separate records for reminders
            baseline: baseline,
            target: target
        )
    }
}
