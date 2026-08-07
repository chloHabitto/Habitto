# Habitto Architecture Overview

## Current Architecture (Updated August 2026)

This document provides a comprehensive overview of Habitto's current architecture, reflecting the live data path and cloud sync approach verified in the codebase.

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Habitto App                              │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer (SwiftUI Views)                        │
│  ├── HomeView, HabitEditView, OverviewView, etc.             │
│  └── Tab-based navigation with custom UI components        │
├─────────────────────────────────────────────────────────────┤
│  Business Logic Layer                                       │
│  ├── HabitRepository.shared (Live UI-facing coordinator)   │
│  ├── DataValidationService (Data integrity)                │
│  ├── MigrationService (Core/Services — UI orchestration)   │
│  └── Analytics Services (Performance, User, Data Usage)    │
├─────────────────────────────────────────────────────────────┤
│  Data Access Layer                                          │
│  ├── HabitStore (actor backing HabitRepository)            │
│  └── HabitRepositoryProtocol (+ alternate protocol stack)  │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer (Protocol-based)                            │
│  ├── SwiftDataStorage (Primary local persistence)          │
│  ├── UserDefaultsStorage (legacy / migration-only paths)   │
│  └── Firestore helpers (cloud sync / backup payloads)      │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer                                       │
│  ├── BackgroundQueueManager (Performance)                  │
│  ├── SyncEngine (Firebase/Firestore sync)                   │
│  ├── UserDefaultsWrapper (Type-safe access)                │
│  ├── DateUtilities & ISO8601DateHelper (Date handling)     │
│  └── TestRunner (Comprehensive testing)                    │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow

### Current Data Flow
```
User Action
    ↓
SwiftUI View
    ↓
HabitRepository.shared (@MainActor)
    ↓
HabitStore (actor)
    ↓
SwiftDataStorage / SwiftDataContainer
    ↓
SwiftData (on-device)
    ↓
SyncEngine (when signed in) → Firebase/Firestore
```

Optional backups (separate from habit record sync): `CloudStorageManager` / `BackupStorageCoordinator` → iCloud Drive documents. More-tab iCloud label uses `ICloudStatusManager` (account status only).

## 📊 Key Components

### 1. **HabitRepository** (`Core/Data/HabitRepository.swift`) — live UI layer
- **Purpose**: Central data management for SwiftUI (`HabitRepository.shared`)
- **Features**: 
  - `@MainActor` facade over `HabitStore`
  - Performance monitoring integration
  - User analytics tracking
  - Data usage analytics
- **Status**: ✅ Active — this is the production entry point for the app UI

### 2. **Protocol-based repository stack** (non-UI / alternate paths)
- **HabitRepositoryProtocol**: Interface used by Legacy/Normalized adapters
- **Status**: Present in the codebase for alternate / normalized-data work; UI does not go through these types today

### 3. **Storage Layer (Protocol-based)**
- **SwiftDataStorage** (`Core/Data/SwiftData/SwiftDataStorage.swift`): Primary local persistence used via `HabitStore`
- **UserDefaultsStorage**: Legacy / migration-only paths (not the live habit store)
  - Still constructed for migrations, retention helpers, and factory leftovers history
  - Type-safe UserDefaultsWrapper integration where used
- **Status**: ✅ SwiftData primary; UserDefaults legacy/migration-only

### 4. **Data Validation & Integrity**
- **DataValidationService**: Validates habit data before save/load
- **DataIntegrityChecker**: Continuous data consistency monitoring
- **HabitValidator**: Individual habit validation
- **Status**: ✅ Fully implemented

### 5. **Migration System**
- **DataMigrationManager** (`Core/Data/Migration/`): Orchestrates migration steps
- **MigrationService** (`Core/Services/MigrationService.swift`): UI integration and progress tracking
- **StorageMigrations**: Storage type changes
- **DataFormatMigrations**: Data model changes
- **Status**: ✅ Implemented and ready

### 6. **Performance & Analytics**
- **PerformanceMetrics**: Tracks app performance
- **UserAnalytics**: Tracks user behavior
- **DataUsageAnalytics**: Monitors data usage patterns
- **BackgroundQueueManager**: Offloads heavy operations
- **Status**: ✅ Fully implemented

### 7. **Cloud sync**
- **Primary cloud path**: Firebase/Firestore backup & sync (`SyncEngine`, not CloudKit record sync)
- **iCloud account status UI**: `ICloudStatusManager` (More tab status label only)
- **iCloud Drive backups**: `CloudStorageManager` / `BackupStorageCoordinator` (document storage)
- **Status**: CloudKit habit-sync scaffolding removed; entitlements may still list CloudKit for documents/status checks

### 8. **Utilities & Infrastructure**
- **UserDefaultsWrapper**: Type-safe UserDefaults access
- **DateUtilities**: Comprehensive date operations
- **ISO8601DateHelper**: ISO 8601 date formatting
- **TestRunner**: Comprehensive unit testing
- **Status**: ✅ All implemented and working

## 🔧 Technical Implementation Details

### Swift 6 Concurrency
- **@MainActor**: Applied to UI-related classes
- **Background Queues**: Heavy operations offloaded
- **Async/Await**: Modern concurrency patterns
- **Thread Safety**: Proper isolation and synchronization (including `HabitStore` actor)

### Data Storage Strategy
- **Primary**: SwiftData via `HabitStore` / `SwiftDataStorage`
- **Legacy**: UserDefaults for migration and secondary helpers only
- **Cloud**: Firebase/Firestore for authenticated (including anonymous) users
- **Backups**: Optional iCloud Drive document backups

### Error Handling
- **DataError**: Comprehensive error types
- **DataErrorHandler**: Centralized error management
- **Validation**: Pre-save data validation
- **Recovery**: Graceful error recovery

### Testing
- **Unit Tests**: Comprehensive test coverage
- **Integration Tests**: End-to-end testing
- **Performance Tests**: Performance benchmarking
- **DST Tests**: Daylight saving time handling
- **Data Integrity Tests**: Data consistency validation
- **Firestore Rules Tests**: `npm run emu:test` against `firestore.rules`

## 📈 Performance Optimizations

### Background Processing
- **BackgroundQueueManager**: Offloads heavy operations
- **Serial Queues**: Ordered operations when needed
- **Main Thread**: UI updates only on main thread

### Caching & Memory Management
- **Smart Caching**: Avoid redundant operations
- **History Capping**: Prevents unlimited growth
- **Memory Monitoring**: Track memory usage

### Data Efficiency
- **SwiftData models**: Structured local persistence
- **Debounced Saves**: Prevent excessive I/O where used
- **Type Safety**: Prevent runtime errors

## 🔒 Security & Privacy

### Data Classification
| Data Type | Storage Location | Security Level |
|-----------|------------------|----------------|
| **Authentication** | Firebase Auth | High (OAuth / anonymous) |
| **Sensitive Info** | iOS Keychain | High (Hardware) |
| **Habit Data** | SwiftData (local) | Medium (Local) |
| **Synced Habit Data** | Firebase/Firestore | High (rules + auth) |
| **Optional Backups** | iCloud Drive documents | High (Apple account) |

### Privacy Principles
- **Local First**: Data stays on device
- **User Control**: Users own their data
- **Minimal Collection**: Only necessary data
- **Transparent**: Clear data usage

## 🚀 Future Roadmap

### Near-term (active direction)
- Harden Firebase/Firestore sync (security rules, SyncEngine reliability)
- Improve optional backup / restore UX (iCloud Drive + local)
- Continue SwiftData schema migrations as the product evolves

### Longer-term ideas
- Deeper analytics and insights
- Social / sharing features
- Custom themes and personalization

*(Legacy “Phase 1 Core Data / Phase 2 CloudKit habit sync” plans are obsolete — CloudKit habit-sync scaffolding was removed; Core Data is not the active store.)*

## 🧪 Testing Strategy

### Test Coverage
- **Unit Tests**: Individual component testing
- **Integration Tests**: Component interaction testing
- **Performance Tests**: Speed and memory testing
- **DST Tests**: Time zone handling
- **Data Integrity Tests**: Data consistency
- **Firestore Rules**: Jest + emulator (`Tests/firestore.rules.test.js`)

### Test Categories
1. **Streak Calculations**: Consecutive days, gaps, DST
2. **Data Validation**: Invalid data detection
3. **Migration**: Storage migration testing
4. **Performance**: Large dataset handling
5. **Integration**: End-to-end workflows

## 📚 Documentation Structure

### Current Documentation
- **ARCHITECTURE_OVERVIEW.md**: This file - high-level architecture
- **FOLDER_STRUCTURE.md**: Directory layout
- **FIREBASE_ARCHITECTURE.md**: Firebase usage clarification
- **README.md**: Project overview
- **Docs/Features/**: Feature guides and flags
- **Docs/data/**: Schema / storage inventory

### Documentation Updates
- ✅ Updated to reflect SwiftData-primary local store
- ✅ Corrected Firebase/Firestore as live cloud sync path
- ✅ Removed obsolete Core Data / CloudKit habit-sync roadmap framing
- ✅ Updated data flow diagrams

## 🎯 Key Benefits

### For Developers
- **Clear Architecture**: Easy to understand and maintain
- **Modular Design**: Components can be updated independently
- **Type Safety**: Compile-time error prevention
- **Comprehensive Testing**: Reliable codebase

### For Users
- **Performance**: Fast and responsive
- **Reliability**: Stable and consistent
- **Privacy**: Local-first with optional cloud sync
- **Offline**: Works without internet; syncs when signed in

## 🔍 Monitoring & Analytics

### Performance Monitoring
- **Load Times**: Track data loading performance
- **Save Times**: Monitor data persistence speed
- **Memory Usage**: Track memory consumption
- **Background Operations**: Monitor queue performance

### User Analytics
- **Habit Creation**: Track habit creation patterns
- **Completion Rates**: Monitor habit completion
- **Feature Usage**: Track feature adoption
- **User Engagement**: Monitor app usage

### Data Usage Analytics
- **Storage Usage**: Track data storage patterns
- **Cache Performance**: Monitor cache efficiency
- **Migration Success**: Track migration completion
- **Error Rates**: Monitor data operation errors

## 🛠️ Development Guidelines

### Code Organization
- **Protocol-First**: Define interfaces before implementations
- **Actor / MainActor boundaries**: Keep store and UI isolation clear
- **Background Operations**: Offload heavy work
- **Error Handling**: Comprehensive error management

### Testing Requirements
- **Unit Tests**: All new components
- **Integration Tests**: Component interactions
- **Performance Tests**: Large dataset handling
- **DST Tests**: Time zone edge cases
- **Rules Tests**: Update Firestore rules tests when changing `firestore.rules`

### Documentation Standards
- **Architecture Docs**: Keep up to date with the live path
- **API Documentation**: Document public interfaces
- **Migration Guides**: Document breaking changes
- **Performance Notes**: Document optimizations

---

**Last Updated**: August 2026  
**Architecture Version**: 3.0  
**Status**: Production — SwiftData local + Firebase/Firestore sync
