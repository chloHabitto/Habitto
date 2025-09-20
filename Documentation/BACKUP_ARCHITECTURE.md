# Backup System Architecture

## Overview

The Habitto backup system provides comprehensive data protection, restoration capabilities, and cross-device synchronization. It supports multiple storage providers, automatic scheduling, and enterprise-grade reliability features.

## Architecture Components

### 1. Core Services

#### BackupManager
- **Purpose**: Central orchestrator for backup operations
- **Responsibilities**:
  - Data serialization and compression
  - Backup file creation and validation
  - Restoration from backup files
  - Error handling and retry logic
  - Metadata tracking and integrity verification

#### BackupScheduler
- **Purpose**: Manages automatic backup scheduling
- **Responsibilities**:
  - Background task registration (`BGAppRefreshTask`)
  - Frequency-based scheduling (Daily/Weekly/Monthly)
  - Network condition monitoring (WiFi-only option)
  - Settings persistence per user

#### BackupStorageCoordinator
- **Purpose**: Unified interface for multiple storage providers
- **Responsibilities**:
  - Provider selection and fallback logic
  - Storage provider status management
  - Backup distribution across providers
  - Configuration management

#### BackupSettingsManager
- **Purpose**: Centralized settings persistence and synchronization
- **Responsibilities**:
  - User-specific settings storage
  - Settings validation and export/import
  - Cross-component settings synchronization
  - Authentication-aware settings management

### 2. Storage Providers

#### iCloud Drive Integration
```swift
CloudStorageManager.shared
```
- **Features**: Native iCloud Drive integration
- **Benefits**: Seamless iOS ecosystem integration
- **Limitations**: Requires iCloud account, subject to Apple's sync timing

#### Google Drive Integration
```swift
GoogleDriveManager.shared
```
- **Features**: Google Drive API integration
- **Benefits**: Cross-platform compatibility
- **Limitations**: Requires Google account, third-party dependency

#### Local Storage
- **Features**: Device-only storage
- **Benefits**: No network dependency, fast access
- **Limitations**: No cross-device sync, device-bound

### 3. Data Models

#### BackupData
```swift
struct BackupData: Codable {
    let metadata: BackupMetadata
    let habits: [HabitData]?
    let userSettings: BackupUserSettings?
    let legacyData: LegacyBackupData?
}
```

#### BackupMetadata
```swift
struct BackupMetadata: Codable {
    let backupId: String
    let version: String
    let createdAt: Date
    let deviceInfo: String
    let appVersion: String
    let userId: String
}
```

#### BackupFileInfo
```swift
struct BackupFileInfo: Codable {
    let fileName: String
    let fileSize: Int64
    let createdAt: Date
    let habitCount: Int
    let formattedSize: String
}
```

### 4. Error Handling

#### BackupError Enum
```swift
enum BackupError: Error {
    case fileNotFound(String)
    case invalidData(String)
    case compressionFailed(String)
    case encryptionFailed(String)
    case networkError(String)
    case quotaExceeded(String)
    case authenticationExpired(String)
    // ... comprehensive error coverage
}
```

#### Retry Mechanism
- **Exponential Backoff**: 2^attempt seconds delay
- **Maximum Attempts**: 3 retries per operation
- **Retryable Errors**: Network, temporary storage, authentication issues

### 5. Security & Privacy

#### Data Protection
- **Compression**: LZFSE algorithm for size reduction
- **Encryption**: Optional AES-256 encryption (future enhancement)
- **Validation**: SHA256 checksums for integrity verification
- **Access Control**: User-specific backup isolation

#### Privacy Compliance
- **No PII Logging**: User identifiers redacted from logs
- **Local Processing**: Data processed on-device before upload
- **User Control**: Complete backup deletion and export capabilities

## Data Flow

### Backup Creation Flow
```
1. User Action / Scheduled Trigger
   ↓
2. BackupManager.createBackup()
   ↓
3. Data Collection (Habits, Settings, Legacy Data)
   ↓
4. Serialization & Compression
   ↓
5. Integrity Validation (SHA256)
   ↓
6. Storage Distribution (iCloud/Google/Local)
   ↓
7. Metadata Update & Notification
```

### Backup Restoration Flow
```
1. User Selection of Backup File
   ↓
2. BackupManager.restoreFromData()
   ↓
3. Data Validation & Version Check
   ↓
4. Existing Data Backup (Safety)
   ↓
5. Data Clearing & Restoration
   ↓
6. Settings Application
   ↓
7. Verification & User Notification
```

### Settings Synchronization Flow
```
1. User Changes Settings
   ↓
2. BackupSettingsManager.saveAllSettings()
   ↓
3. Update BackupScheduler Configuration
   ↓
4. Update BackupStorageCoordinator Configuration
   ↓
5. Persist to UserDefaults (User-Specific)
   ↓
6. Notify Components of Changes
```

## Configuration Options

### Backup Frequency
- **Manual**: User-initiated only
- **Daily**: Every 24 hours
- **Weekly**: Every 7 days
- **Monthly**: Every 30 days

### Storage Providers
- **Automatic**: Smart provider selection
- **iCloud Only**: Apple ecosystem integration
- **Google Drive Only**: Cross-platform compatibility
- **Local Only**: Device-bound storage
- **Multiple**: Redundant storage across providers

### Advanced Options
- **WiFi Only**: Network condition checking
- **Compression**: Data size optimization
- **Encryption**: Data security (planned)
- **Retention**: Automatic cleanup of old backups
- **Notifications**: User feedback on operations

## API Reference

### BackupManager
```swift
// Create a new backup
func createBackup() async throws -> BackupFileInfo

// Restore from backup data
func restoreFromData(_ data: Data) async throws -> RestoreResult

// Verify backup integrity
func verifyBackup(_ url: URL) async throws -> Bool

// Get backup data without creating file
func getBackupData() async throws -> BackupData
```

### BackupScheduler
```swift
// Update backup schedule
func updateSchedule(isEnabled: Bool, frequency: BackupFrequency, networkCondition: NetworkCondition)

// Load current configuration
static func loadScheduleConfig() -> BackupScheduleConfig

// Register background tasks
func registerBackgroundTasks()

// Check network conditions
func isWiFiConnected() -> Bool
```

### BackupStorageCoordinator
```swift
// Perform backup with provider selection
func performBackup() async throws -> BackupStorageResult

// List available backups
func listAvailableBackups() async throws -> [BackupStorageFileInfo]

// Restore from specific backup
func restoreBackup(_ backupFile: BackupStorageFileInfo) async throws -> RestoreResult

// Update provider configuration
func updateProviderStatus()
```

### BackupSettingsManager
```swift
// Save all settings
func saveAllSettings()

// Load all settings
private func loadAllSettings()

// Export settings to JSON
func exportSettings() -> Data?

// Import settings from JSON
func importSettings(from data: Data) throws

// Validate current configuration
func validateSettings() -> [String]
```

## Testing

### BackupTestingSuite
Comprehensive testing framework covering:

#### Core Functionality Tests
- **Backup Creation**: Data serialization and file generation
- **Backup Validation**: Integrity verification and metadata checking
- **Backup Restoration**: Data recovery and settings application
- **Settings Persistence**: Configuration saving and loading

#### Integration Tests
- **Scheduler Integration**: Background task and timing verification
- **Storage Coordinator**: Provider selection and fallback testing
- **Network Conditions**: WiFi detection and connectivity testing
- **Background Tasks**: iOS background processing validation

#### Error Handling Tests
- **Invalid Data**: Malformed backup file handling
- **Network Failures**: Offline and connectivity error scenarios
- **Storage Quotas**: Space limitation handling
- **Authentication**: Token expiration and renewal testing

### Test Execution
```swift
// Run comprehensive test suite
let testingSuite = BackupTestingSuite.shared
await testingSuite.runAllTests()

// Get test results
let results = testingSuite.testResults
let summary = testingSuite.getTestSummary()
```

## Performance Considerations

### Memory Management
- **Streaming**: Large backups processed in chunks
- **Compression**: Reduces memory footprint during processing
- **Cleanup**: Automatic resource disposal after operations

### Network Optimization
- **WiFi Detection**: Avoids cellular data usage
- **Compression**: Reduces upload/download time
- **Retry Logic**: Handles network interruptions gracefully

### Storage Efficiency
- **LZFSE Compression**: iOS-optimized algorithm
- **Incremental Backups**: Only changed data (future enhancement)
- **Retention Policy**: Automatic cleanup of old backups

## Troubleshooting

### Common Issues

#### Backup Creation Fails
1. **Check Storage Space**: Ensure sufficient device storage
2. **Verify Network**: Confirm internet connectivity for cloud providers
3. **Authentication**: Verify cloud account sign-in status
4. **Permissions**: Ensure app has required permissions

#### Restoration Issues
1. **File Integrity**: Verify backup file is not corrupted
2. **Version Compatibility**: Check app version compatibility
3. **Data Conflicts**: Resolve conflicts with existing data
4. **Storage Space**: Ensure sufficient space for restoration

#### Settings Not Persisting
1. **User Authentication**: Verify user is properly signed in
2. **Storage Permissions**: Check UserDefaults access
3. **App State**: Ensure app is not in background during save
4. **Validation**: Check for configuration validation errors

### Debug Information
```swift
// Enable debug logging
Logger(subsystem: "com.habitto.backup", category: "debug")

// Check backup status
let backupManager = BackupManager.shared
let lastBackup = backupManager.lastBackupDate

// Verify settings
let settingsManager = BackupSettingsManager.shared
let issues = settingsManager.validateSettings()
```

## Future Enhancements

### Planned Features
- **Incremental Backups**: Only backup changed data
- **Encryption**: AES-256 data protection
- **Cross-Platform**: Android backup support
- **Cloud Sync**: Real-time synchronization
- **Backup Analytics**: Usage statistics and optimization

### Performance Improvements
- **Parallel Processing**: Concurrent backup operations
- **Smart Scheduling**: AI-based optimal timing
- **Bandwidth Management**: Adaptive upload speeds
- **Cache Optimization**: Intelligent data caching

## Security Considerations

### Data Protection
- **Local Processing**: All data processed on-device
- **Secure Transmission**: HTTPS/TLS for all network operations
- **Access Control**: User-specific data isolation
- **Audit Trail**: Comprehensive operation logging

### Privacy Compliance
- **GDPR**: Right to deletion and data portability
- **CCPA**: Data transparency and control
- **COPPA**: Child privacy protection
- **SOC 2**: Enterprise security standards

## Support & Maintenance

### Monitoring
- **Health Checks**: Automated system status monitoring
- **Performance Metrics**: Backup success rates and timing
- **Error Tracking**: Comprehensive error logging and analysis
- **User Feedback**: In-app feedback and support channels

### Updates
- **Version Compatibility**: Backward compatibility for backup files
- **Migration Support**: Automatic data format updates
- **Feature Flags**: Gradual rollout of new functionality
- **Rollback Capability**: Safe reversion to previous versions
