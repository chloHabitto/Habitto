# Habitto - Habit Tracking App

A comprehensive habit tracking application built with SwiftUI, featuring a modern Repository pattern architecture with comprehensive data validation, performance monitoring, and future CloudKit sync capabilities.

## 🏗️ Architecture Overview

Habitto uses a modern, scalable architecture with clear separation of concerns:

- **Repository Pattern**: Clean data access abstraction
- **Protocol-Based Storage**: Interchangeable storage implementations
- **Swift 6 Concurrency**: Modern async/await patterns with @MainActor
- **Comprehensive Testing**: Unit tests for all critical functionality
- **Performance Monitoring**: Built-in analytics and performance tracking
- **Data Validation**: Robust data integrity and validation
- **Migration System**: Seamless data migration capabilities
- **CloudKit Ready**: Prepared for future cross-device sync

## 📁 Project Structure

The project has been reorganized for better maintainability and clarity. Here's the current structure:

### 🚀 App
```
App/
└── HabittoApp.swift         # Main app entry point with migration integration
```

### 🏗️ Core Architecture
```
Core/
├── Data/                    # Data management and persistence
│   ├── HabitRepository.swift           # Main data coordinator
│   ├── HabitRepositoryNew.swift        # Repository facade
│   ├── HabitRepositoryImpl.swift       # Repository implementation
│   ├── CoreDataManager.swift          # Core Data management
│   ├── CloudKitManager.swift          # CloudKit integration
│   ├── Protocols/                      # Data access protocols
│   │   └── DataStorageProtocol.swift
│   ├── Storage/                        # Storage implementations
│   │   ├── UserDefaultsStorage.swift  # Primary storage (active)
│   │   └── CoreDataStorage.swift      # Future storage (disabled)
│   ├── Repository/                     # Repository implementations
│   │   └── HabitRepositoryImpl.swift
│   ├── Factory/                        # Storage factory
│   │   └── StorageFactory.swift
│   ├── Migration/                      # Data migration system
│   │   ├── DataMigrationManager.swift
│   │   ├── MigrationService.swift
│   │   ├── StorageMigrations.swift
│   │   └── DataFormatMigrations.swift
│   ├── CloudKit/                       # CloudKit integration
│   │   ├── CloudKitModels.swift
│   │   ├── CloudKitSyncManager.swift
│   │   ├── CloudKitSchema.swift
│   │   ├── CloudKitConflictResolver.swift
│   │   └── CloudKitIntegrationService.swift
│   └── Background/                     # Background processing
│       └── BackgroundQueueManager.swift
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
Documentation/
├── ARCHITECTURE_OVERVIEW.md    # Comprehensive architecture overview
├── CORE_DATA_IMPLEMENTATION.md # Core Data implementation details
├── FIREBASE_ARCHITECTURE.md    # Firebase usage and data architecture
├── HABIT_EDITING_SUMMARY.md    # Habit editing functionality
├── OPTIMIZED_STORAGE_IMPLEMENTATION.md # UserDefaults optimization
├── DATA_SECURITY_GUIDELINES.md # Security and privacy guidelines
└── PROJECT_STRUCTURE.md        # Detailed project structure documentation
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
13. **Local-First**: Data stays on device with optional cloud sync
14. **Privacy-Focused**: Clear data classification and minimal collection
15. **Secure Storage**: Sensitive data in Keychain, user data in UserDefaults
16. **Future-Ready**: CloudKit integration prepared for cross-device sync

### 📈 **Scalability & Maintainability**
17. **Modular Design**: Components can be updated independently
18. **Clear Separation**: UI, business logic, and data layers properly separated
19. **Easy Navigation**: Logical file organization for quick development
20. **iOS Best Practices**: Follows Apple's recommended patterns and guidelines

## 🚀 Current Features & Capabilities

### **Data Management**
- ✅ **Repository Pattern**: Clean data access with protocol-based storage
- ✅ **UserDefaults Storage**: Optimized individual habit storage with history capping
- ✅ **Data Validation**: Comprehensive validation before save/load operations
- ✅ **Migration System**: Automatic migration from old storage formats
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

### **Future-Ready Architecture**
- 🔄 **CloudKit Integration**: Prepared for cross-device synchronization
- 🔄 **Core Data Migration**: Ready for structured database implementation
- 🔄 **Conflict Resolution**: CloudKit conflict handling system
- 🔄 **Advanced Analytics**: AI-powered insights and recommendations

## 🔥 Running with Firebase Emulator Suite

Habitto supports Firebase Firestore for cloud data synchronization. For local development and testing, you can use the Firebase Emulator Suite.

### Prerequisites

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```

2. **Install Firebase Emulators**:
   ```bash
   firebase init emulators
   ```
   Select:
   - ✅ Firestore
   - ✅ Authentication

### Starting the Emulators

```bash
# Start all emulators
firebase emulators:start

# Or start specific emulators
firebase emulators:start --only firestore,auth
```

The emulators will start on:
- **Firestore**: `localhost:8080`
- **Auth**: `localhost:9099`
- **Emulator UI**: `http://localhost:4000`

### Running Tests with Emulator

```bash
# Set environment variables
export USE_FIREBASE_EMULATOR=true
export FIRESTORE_EMULATOR_HOST=localhost:8080
export AUTH_EMULATOR_HOST=localhost:9099

# Run tests
xcodebuild test -scheme Habitto -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Configuration

The app automatically detects emulator configuration via environment variables:
- `USE_FIREBASE_EMULATOR`: Set to "true" to use emulators
- `FIRESTORE_EMULATOR_HOST`: Firestore emulator address (default: localhost:8080)
- `AUTH_EMULATOR_HOST`: Auth emulator address (default: localhost:9099)

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

**Path**: `Views/Screens/HabitsFirestoreDemoView.swift`

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
- 🔄 **Core Data**: Migrate from UserDefaults to Core Data for better performance
- 🔄 **CloudKit Sync**: Enable cross-device synchronization
- 🔄 **Advanced Analytics**: Add AI-powered insights and recommendations

This architecture follows iOS development best practices and provides a solid foundation for future development while maintaining backward compatibility.
