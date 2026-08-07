# Habitto - Habit Tracking App

A comprehensive habit tracking application built with SwiftUI, featuring a modern Repository pattern architecture with SwiftData local persistence, Firebase/Firestore cloud sync, comprehensive data validation, and performance monitoring.

## 🏗️ Architecture Overview

Habitto uses a modern, scalable architecture with clear separation of concerns:

- **Repository Pattern**: Clean data access abstraction
- **Protocol-Based Storage**: Interchangeable storage implementations
- **Swift 6 Concurrency**: Modern async/await patterns with @MainActor
- **Comprehensive Testing**: Unit tests for all critical functionality
- **Performance Monitoring**: Built-in analytics and performance tracking
- **Data Validation**: Robust data integrity and validation
- **Migration System**: Seamless data migration capabilities
- **Cloud Sync**: Firebase/Firestore for habit data; iCloud Drive for optional backups

## 📁 Project Structure

The project has been reorganized for better maintainability and clarity. Here's the current structure:

### 🚀 App
```
App/
├── HabittoApp.swift         # Main app entry point with migration integration
└── AppFirebase.swift        # Firebase configuration and initialization
```

### 🏗️ Core Architecture
```
Core/
├── Data/                    # Data management and persistence
│   ├── HabitRepository.swift           # Live UI-facing singleton (HabitRepository.shared)
│   ├── DataStorageProtocol.swift       # Data access protocols
│   ├── FirestoreRepository.swift       # Firestore repository helpers
│   ├── SyncEngine.swift                # Sync engine
│   ├── Store/                          # HabitStore actor (backs HabitRepository)
│   │   └── HabitStore.swift
│   ├── SwiftData/                      # SwiftData models + primary local store
│   │   └── SwiftDataStorage.swift     # Primary local persistence (via HabitStore)
│   ├── Storage/                        # Storage implementations
│   │   ├── UserDefaultsStorage.swift  # Legacy / migration paths
│   │   └── FirestoreStorage.swift
│   ├── Repositories/                   # Protocol-based repository stack (non-UI)
│   │   └── HabitRepositoryProtocol.swift
│   ├── Migration/                      # Data migration system
│   │   ├── DataMigrationManager.swift
│   │   ├── StorageMigrations.swift
│   │   └── DataFormatMigrations.swift
│   └── BackgroundQueueManager.swift    # Background processing
├── Services/                # Business services
│   └── MigrationService.swift          # Migration UI orchestration
├── Models/                  # Data models
│   └── Habit.swift
├── Validation/              # Data validation
│   ├── DataValidation.swift
│   ├── DataIntegrityChecker.swift
│   └── DataValidationService.swift
├── ErrorHandling/           # Error management
│   └── DataError.swift
├── Analytics/               # Performance and user analytics
│   ├── PerformanceMetrics.swift
│   ├── UserAnalytics.swift
│   └── DataUsageAnalytics.swift
├── Constants/               # App constants and configuration
│   ├── EmojiData.swift
│   └── ScheduleOptions.swift
├── Extensions/              # Swift extensions
│   ├── DateExtensions.swift
│   └── ViewExtensions.swift
└── UI/                      # Reusable UI components
    ├── Buttons/            # Button system and styles
    ├── BottomSheets/        # Bottom sheet components
    ├── Cards/               # Card-based UI components
    ├── Common/              # Shared UI components
    ├── Forms/               # Form-related components
    ├── Items/               # List item components
    ├── Navigation/          # Navigation components
    └── Selection/           # Selection and picker components
```

### 🖥️ Views
```
Views/
├── Screens/                 # Main screen views
│   ├── HomeView.swift
│   ├── OverviewView.swift
│   ├── HabitDetailView.swift
│   ├── HabitEditView.swift
│   └── DateCalendarSettingsView.swift
├── Tabs/                    # Tab-based navigation views
│   ├── HomeTabView.swift
│   ├── HabitsTabView.swift
│   ├── ProgressTabView.swift
│   └── MoreTabView.swift
├── Flows/                   # Multi-step flow views
│   ├── CreateHabitFlowView.swift
│   ├── CreateHabitStep1View.swift
│   ├── CreateHabitStep2View.swift
│   └── CreateHabitView.swift
├── Modals/                  # Modal and overlay views
│   └── NotificationView.swift
├── Features/                # Feature-specific views
└── Shared/                  # Shared view components
```

### 🛠️ Utilities
```
Utils/
├── Design/                  # Design system utilities
│   ├── ColorSystem.swift    # Color definitions and themes
│   ├── FontSystem.swift     # Typography system
│   └── DatePreferences.swift # Date handling utilities
├── Date/                    # Date utilities
│   ├── ISO8601DateHelper.swift # ISO 8601 date formatting
│   └── DateUtilities.swift  # Comprehensive date operations
├── Storage/                 # Storage utilities
│   └── UserDefaultsWrapper.swift # Type-safe UserDefaults access
├── Managers/                # Manager classes
│   └── NotificationManager.swift # Local notification management
└── Scripts/                 # Build and utility scripts
    ├── create_color_sets.py
    └── create_dark_mode_colors.py
```

### 🎨 Assets
```
Assets/
├── Colors.xcassets/         # Color definitions and themes
│   ├── AccentColor.colorset/
│   ├── AppIcon.appiconset/
│   └── Primitive color variants (yellow50-900, green50-900, red50-900, navy50-900, pastelBlue50-900, grey50-900, greyBlack, greyWhite)
└── Icons.xcassets/          # App icons and UI elements
    ├── Individual icon imagesets
    └── Bottom navigation icons
```

### 📚 Documentation
```
Docs/
├── Architecture/               # Architecture & structure
│   ├── ARCHITECTURE_OVERVIEW.md
│   ├── DATA_ARCHITECTURE.md
│   ├── DATA_SECURITY_GUIDELINES.md
│   ├── FIREBASE_ARCHITECTURE.md
│   ├── FOLDER_STRUCTURE.md
│   └── …
├── Product/                    # Product-facing overviews
│   ├── APP_OVERVIEW.md
│   └── SUBSCRIPTION_ANALYSIS.md
├── Features/                   # Feature guides & flags
├── Guides/                     # Setup guides
├── data/                       # Schema / storage inventory
└── archive/                    # Historical investigation & fix notes
```

### 🧪 Tests
```
Tests/
├── HabitEditTest.swift      # Habit editing functionality tests
├── TestRunner.swift         # Comprehensive test runner
└── SimpleTestRunner.swift   # Alternative test runner
```

## Key Benefits of Current Architecture

### 🏗️ **Modern Architecture**
1. **Repository Pattern**: Clean data access abstraction with protocol-based storage
2. **Swift 6 Concurrency**: Modern async/await patterns with proper @MainActor isolation
3. **Protocol-Based Design**: Interchangeable storage implementations for future flexibility
4. **Dependency Injection**: Factory pattern for clean dependency management

### 🚀 **Performance & Reliability**
5. **Background Processing**: Heavy operations offloaded to background queues
6. **Type-Safe Storage**: UserDefaultsWrapper prevents runtime errors
7. **Data Validation**: Comprehensive validation and integrity checking
8. **Performance Monitoring**: Built-in analytics and performance tracking

### 🧪 **Testing & Quality**
9. **Comprehensive Testing**: Unit tests for all critical functionality including DST handling
10. **Data Integrity**: Continuous monitoring and validation
11. **Migration System**: Seamless data migration capabilities
12. **Error Handling**: Robust error management and recovery

### 🔒 **Security & Privacy**
13. **Local-First**: Data stays on device with optional Firebase/Firestore sync
14. **Privacy-Focused**: Clear data classification and minimal collection
15. **Secure Storage**: Sensitive data in Keychain; habit data in SwiftData
16. **Cloud Backup**: Optional iCloud Drive backups via the backup subsystem

### 📈 **Scalability & Maintainability**
17. **Modular Design**: Components can be updated independently
18. **Clear Separation**: UI, business logic, and data layers properly separated
19. **Easy Navigation**: Logical file organization for quick development
20. **iOS Best Practices**: Follows Apple's recommended patterns and guidelines

## 🚀 Current Features & Capabilities

### **Data Management**
- ✅ **Repository Pattern**: Clean data access with protocol-based storage
- ✅ **SwiftData Storage**: Primary local persistence via HabitStore
- ✅ **Data Validation**: Comprehensive validation before save/load operations
- ✅ **Migration System**: Automatic migration from legacy storage formats
- ✅ **Background Processing**: Heavy operations offloaded to background queues

### **Performance & Analytics**
- ✅ **Performance Monitoring**: Track load/save times and memory usage
- ✅ **User Analytics**: Monitor user behavior and feature usage
- ✅ **Data Usage Analytics**: Track storage patterns and optimization opportunities
- ✅ **Background Queue Management**: Efficient background task processing

### **Testing & Quality**
- ✅ **Unit Tests**: Comprehensive test coverage for all critical functionality
- ✅ **DST Testing**: Proper handling of Daylight Saving Time transitions
- ✅ **Data Integrity Tests**: Continuous validation of data consistency
- ✅ **Performance Tests**: Benchmarking for large datasets

### **Cloud & Backup**
- ✅ **Firebase/Firestore Sync**: Habit data, completions, progress events, XP
- ✅ **iCloud Drive Backups**: Optional document backups via CloudStorageManager
- ✅ **iCloud Status UI**: Account availability shown on More tab (ICloudStatusManager)

## 🔥 Running with Firebase Emulator Suite

Habitto supports Firebase Firestore for cloud data synchronization. For local development and testing, you can use the Firebase Emulator Suite.

### Prerequisites

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```

2. **Install Node.js Dependencies** (for security rules testing):
   ```bash
   cd /Users/chloe/Desktop/Habitto
   npm install
   ```

3. **Firebase Emulators** (auto-configured via `firebase.json`):
   - ✅ Firestore (port 8080)
   - ✅ Authentication (port 9099)
   - ✅ Emulator UI (port 4000)

### Quick Start Commands

```bash
# Start emulators only
npm run emu:start

# Run security rules tests with emulator
npm run emu:test

# Open emulator UI in browser
npm run emu:ui
```

### Starting the Emulators Manually

```bash
# Start all configured emulators
firebase emulators:start

# Or start specific emulators
firebase emulators:start --only firestore,auth
```

The emulators will start on:
- **Firestore**: `localhost:8080`
- **Auth**: `localhost:9099`
- **Emulator UI**: `http://localhost:4000`

### Running Security Rules Tests

Habitto includes comprehensive Firestore security rules tests using Jest and the Firebase Rules Unit Testing library.

**Test Coverage**:
- ✅ Authentication requirements (50+ tests)
- ✅ User data isolation
- ✅ Habit CRUD validation
- ✅ Goal version immutability
- ✅ Completion date format validation
- ✅ XP state integrity
- ✅ XP ledger immutability (append-only)
- ✅ Streak validation
- ✅ Cross-user access prevention

**Run tests**:
```bash
# Run all security rules tests
npm test

# Run tests in watch mode
npm run test:watch

# Run with coverage report
npm run test:coverage

# Run tests with emulator auto-start
npm run emu:test
```

**Expected Output**:
```
PASS  tests/firestore.rules.test.js
  Authentication Requirements
    ✓ Unauthenticated users cannot read any data (45ms)
    ✓ Unauthenticated users cannot write any data (12ms)
    ✓ Authenticated users can read their own data (18ms)
    ✓ Authenticated users cannot read other users data (15ms)
  Habits Collection Rules
    ✓ User can create valid habit (22ms)
    ✓ User cannot create habit without required fields (14ms)
    ✓ User cannot create habit with invalid type (16ms)
    ... (50+ more tests)

Test Suites: 1 passed, 1 total
Tests:       58 passed, 58 total
Time:        3.421s
```

### Running iOS Tests with Emulator

```bash
# Set environment variables
export USE_FIREBASE_EMULATOR=true
export FIRESTORE_EMULATOR_HOST=localhost:8080
export AUTH_EMULATOR_HOST=localhost:9099

# Run iOS tests
xcodebuild test -scheme Habitto -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Configuration

The app automatically detects emulator configuration via environment variables:
- `USE_FIREBASE_EMULATOR`: Set to "true" to use emulators
- `FIRESTORE_EMULATOR_HOST`: Firestore emulator address (default: localhost:8080)
- `AUTH_EMULATOR_HOST`: Auth emulator address (default: localhost:9099)

### Firestore Security Rules

Security rules are defined in `firestore.rules` and enforce:

1. **User-Scoped Access**: Users can only read/write data under `/users/{auth.uid}/`
2. **Field Validation**:
   - Habit names: 1-100 characters
   - Habit types: 'formation' or 'breaking'
   - Date strings: YYYY-MM-DD format (Europe/Amsterdam)
   - Goals: >= 0
   - Completion counts: >= 0
   - XP: totalXP >= 0, level >= 1
3. **Immutability**:
   - Goal versions cannot be updated (only created/deleted)
   - XP ledger entries are append-only (cannot be updated or deleted)
4. **Data Integrity**:
   - Timestamps required on all writes
   - String length limits enforced
   - Type validation for all fields

### Firestore Indexes

Indexes are defined in `firestore.indexes.json` for optimized queries:
- Goal versions by habit and effective date
- Completions by update time
- XP ledger by timestamp
- Habits by active status and creation date
- Streaks by current streak count

### Safe Development Mode

If `GoogleService-Info.plist` is missing:
- ✅ App runs with mock data
- ✅ Unit tests use fake implementations
- ✅ Banner shows "Firebase not configured"
- ✅ No crashes or errors

This allows development and testing without requiring Firebase credentials.

### Demo Screen

Access the Firebase demo screen to:
- View real-time habit synchronization
- Create, update, and delete habits
- See current authentication status
- Test offline persistence

**Path**: `Views/Screens/FirestoreRepoDemoView.swift`

### Troubleshooting

**App startup lag / SwiftData CloudKit validation noise**:
If you see long startup lag or leftover CloudKit schema-validation messages in console (entitlements may still list CloudKit for documents/status, but habit sync scaffolding is gone):
```bash
# Run the cleanup script
./Scripts/shell/clean_cloudkit_artifacts.sh

# Then in Xcode:
# 1. Product → Clean Build Folder (⌘+Shift+K)
# 2. Product → Run (⌘+R)
```
Habit data sync uses Firebase/Firestore (`SyncEngine`), not CloudKit record sync. See `Docs/Features/FEATURE_FLAGS_README.md` for remaining `cloudkit_sync` flag notes.

**Emulator won't start**:
```bash
# Kill existing emulator processes
lsof -ti:8080,9099,4000 | xargs kill -9

# Restart emulators
npm run emu:start
```

**Tests failing**:
```bash
# Clear emulator data
firebase emulators:start --clear-data

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

**Port conflicts**:
Edit `firebase.json` to change emulator ports if needed.

## Usage Guidelines

- **Core/UI**: Place reusable UI components here
- **Views**: Place screen-specific views here
- **Core/Data**: Place data management code here
- **Utils**: Place utility functions and helpers here
- **Assets**: Use `Image("Icon-name")` for icons and `Color("colorName")` for colors

## Migration Notes

### **Completed Migrations**
- ✅ **Repository Pattern**: Implemented clean data access abstraction
- ✅ **Storage Optimization**: Migrated to individual habit storage with history capping
- ✅ **Swift 6 Concurrency**: Updated to modern async/await patterns
- ✅ **Data Validation**: Added comprehensive validation and integrity checking
- ✅ **Performance Monitoring**: Integrated analytics and performance tracking
- ✅ **Background Processing**: Offloaded heavy operations to background queues
- ✅ **Type-Safe Storage**: Implemented UserDefaultsWrapper for safe data access
- ✅ **Comprehensive Testing**: Added unit tests for all critical functionality

### **Preserved Functionality**
- ✅ All existing UI and user experience preserved
- ✅ No breaking changes to app design or behavior
- ✅ All import statements remain valid
- ✅ Build process unchanged
- ✅ Data migration is automatic and seamless

### **Future Migrations (Planned)**
- 🔄 **Firestore Sync Hardening**: Continue tightening security rules and sync reliability
- 🔄 **Backup UX**: Improve optional iCloud Drive / local backup flows
- 🔄 **Advanced Analytics**: Add deeper insights and recommendations

This architecture follows iOS development best practices and provides a solid foundation for future development while maintaining backward compatibility.
