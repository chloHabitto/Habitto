# Habitto Feature Flags Documentation

## Overview
Feature flags control the rollout of new features, with remote config, regional rollout, and kill switch capabilities.

## Remote JSON Schema

```
{
  "flags": [
    {
      "flag": "challenges",
      "enabled": false,
      "rolloutPercentage": 0.0,
      "cohorts": ["cohort_0"],
      "minAppVersion": "1.0.0",
      "maxAppVersion": "2.0.0",
      "description": "Habit Challenges Feature"
    }
  ],
  "version": "1.0",
  "ttl": 3600,
  "lastUpdated": "2024-09-26T18:30:00Z"
}
```

## Cache TTL
- **Cache Duration**: 1 hour (`cacheTTL: TimeInterval = 3600`)
- **Refresh Strategy**: Background fetch on app launch
- **Fallback**: Local overrides → Cached flags → Defaults

## Cohort Stickiness & Local Override

### Priority Order (highest to lowest):
1. **Local Override** via `setLocalOverride(_ flag: FeatureFlag, enabled: Bool)`
2. **Cached Remote** config (1hr TTL)
3. **Remote Config** via API fetch
4. **Default Values**

### Cohort Assignment:
```swift
private func getUserCohort(userId: String) -> String {
    let hash = hashUserId(userId)
    return "cohort_\(hash % 10)"  // 10 stable cohorts
}
```

## Code Path Gating

### Current Feature Gates:

| Feature | Default | Gated Code Paths |
|---------|---------|------------------|
| `challenges` | OFF | Challenge creation, display |
| `theme_persistence` | OFF | Theme setting storage |
| `i18n_locales` | OFF | Locale-specific UI, data formatting |
| `streak_rules_v2` | OFF | Advanced streak calculations |
| `migration_kill_switch` | ON | Data migration execution |
| `cloudkit_sync` | OFF | CloudKit initialization |
| `field_level_encryption` | OFF | Sensitive data encryption |

### Made OFF by Default Until Implemented ✅

#### CloudKit Sync (`cloudkit_sync = false`)
- Gated in: `CloudKitIntegrationService.startSync()`
- Gated in: `CloudKitManager.initializeCloudKitSync()`
- **Confirmation**: All CloudKit operations disabled by default flag

#### Field-Level Encryption (`field_level_encryption = false`)
- Gated in: `FieldLevelEncryptionManager.encryptField()`
- Gated in: `FieldLevelEncryptionManager.decryptField()`
- **Confirmation**: All encryption operations throw `FeatureFlagError.featureDisabled`

#### Migration Kill Switch Tested (`migration_kill_switch = true`)
- Gated in: `DataMigrationManager.executeMigrations()`
- Gated in: `HabitRepositoryImpl.saveHabits()`
- **Confirmation**: Migration kill switch powered by these gated implementations

## Implementation Evidence

✅ **File: Core/Managers/FeatureFlags.swift (Lines 86-104)**
```swift
func isEnabled(_ flag: FeatureFlag, forUser userId: String? = nil) -> Bool {
    // 1. Check local override first
    if let localOverride = getLocalOverride(for: flag) {
        return localOverride
    }
    
    // 2. Check cached remote value
    if let cachedValue = cachedFlags[flag] {
        return cachedValue
    }
    
    // 3. Check remote config if available
    if let remoteValue = getRemoteValue(for: flag, userId: userId) {
        return remoteValue
    }
    
    // 4. Fall back to default value  
    return flag.defaultValue
}
```

✅ **Remote Config**: https://habitto-config.firebaseapp.com/feature-flags.json

✅ **Cohort Hash**: Stable hash across sessons for user-based features

## GDPR Delete & Encryption Confirmation

These features disabled by default flag because implementation is not fully complete:

1. **CloudKit delete flows** - needs full CloudKit implementation
2. **GDPR purge** - needs instance-wide deletion models 
3. **Encryption key management** - needs key rotation & device loss

**Readiness for activation**: Requires full implementation before enabling.

