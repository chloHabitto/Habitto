# Data Security Guidelines for Habitto

## Overview

This document outlines the proper storage locations for different types of data in Habitto, ensuring sensitive information is protected while maintaining app functionality.

## Data Classification & Storage

### 🔐 **Keychain (High Security)**
**Use for:** Sensitive authentication data and personal identifiers

| Data Type | Key | Reason |
|-----------|-----|--------|
| Apple User Display Names | `AppleUserDisplayName_{userID}` | Personal information, only provided once |
| Firebase Auth Tokens | `FirebaseAuthToken` | Authentication credentials |
| Google Auth Tokens | `GoogleAuthToken` | Authentication credentials |
| User IDs | `UserID` | Personal identifier |
| User Emails | `UserEmail` | Personal information |
| Device Identifiers | `DeviceIdentifier` | Device-specific sensitive data |

### 📱 **UserDefaults (Low Security)**
**Use for:** App preferences, settings, and non-sensitive state

| Data Type | Key | Reason |
|-----------|-----|--------|
| Migration Status | `CoreDataMigrationCompleted` | App state, not sensitive |
| Tutorial Completion | `hasSeenTutorial` | App state, not sensitive |
| Date Preferences | `selectedDateFormat`, `selectedFirstDay` | User preferences |
| Reminder Settings | `planReminderEnabled`, `completionReminderEnabled` | App settings |
| Vacation Data | `VacationData` | User preferences, not personally identifiable |
| Habit Data | `SavedHabits` | User content, not authentication data |

### 🗄️ **Core Data (Future)**
**Use for:** Structured data with relationships and complex queries

| Data Type | Reason |
|-----------|--------|
| Habit Entities | Complex relationships, future CloudKit sync |
| Progress Records | Time-series data, analytics |
| User Preferences | Structured settings with relationships |

## Security Principles

### ✅ **DO Store in Keychain:**
- Authentication tokens and credentials
- Personal identifiers (user IDs, emails)
- Sensitive user data (names, personal info)
- Device-specific sensitive data

### ✅ **DO Store in UserDefaults:**
- App preferences and settings
- UI state and tutorial completion
- Non-sensitive user content
- Migration flags and app state

### ❌ **DON'T Store in UserDefaults:**
- Authentication tokens
- Personal identifiers
- Sensitive user information
- Any data that could compromise user privacy

## Implementation Notes

### Keychain Access
```swift
// Store sensitive data
KeychainManager.shared.storeUserID("user123")
KeychainManager.shared.storeAppleUserDisplayName("John Doe", for: "user123")

// Retrieve sensitive data
let userID = KeychainManager.shared.retrieveUserID()
let displayName = KeychainManager.shared.retrieveAppleUserDisplayName(for: "user123")
```

### UserDefaults Access
```swift
// Store app preferences
UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
UserDefaults.standard.set("MM/dd/yyyy", forKey: "selectedDateFormat")

// Store habit data (non-sensitive)
HabitStorageManager.shared.saveHabits(habits)
```

## Data Lifecycle

### On App Launch
1. Load app preferences from UserDefaults
2. Load habit data from UserDefaults
3. Check authentication state (tokens in Keychain)

### On User Sign-In
1. Store authentication tokens in Keychain
2. Store user identifiers in Keychain
3. Update app state in UserDefaults

### On User Sign-Out
1. Clear all data from Keychain
2. Keep app preferences in UserDefaults
3. Optionally clear habit data (user choice)

### On App Uninstall
- Keychain data is automatically cleared by iOS
- UserDefaults data is automatically cleared by iOS
- No manual cleanup required

## Migration Strategy

When moving from UserDefaults to Keychain:

1. **Identify sensitive data** currently in UserDefaults
2. **Create migration function** to move data to Keychain
3. **Update code** to use Keychain for sensitive data
4. **Remove sensitive data** from UserDefaults
5. **Test thoroughly** to ensure no data loss

## Error Handling

### Keychain Errors
- Gracefully handle keychain access failures
- Provide fallback behavior for missing data
- Log errors for debugging (without sensitive data)

### UserDefaults Errors
- Validate data before storing
- Provide default values for missing data
- Handle data corruption gracefully

## Testing

### Security Testing
- Verify sensitive data is not in UserDefaults
- Test keychain access on different devices
- Verify data is cleared on sign-out

### Functionality Testing
- Ensure app works without keychain access
- Test data migration scenarios
- Verify data persistence across app launches

## Future Considerations

### CloudKit Integration
- Sensitive data stays in Keychain (local only)
- Non-sensitive data syncs via CloudKit
- User preferences can sync across devices

### Data Encryption
- Keychain provides automatic encryption
- Consider additional encryption for highly sensitive data
- Implement data versioning for future changes

## Compliance

### Privacy Regulations
- Follow GDPR principles for data minimization
- Implement data retention policies
- Provide user control over data deletion

### Security Best Practices
- Use secure coding practices
- Regular security audits
- Keep dependencies updated
