# Habitto - Folder Structure Documentation

This document provides a comprehensive overview of the Habitto project's folder structure, explaining the purpose and organization of each directory and key files.

**Last Updated**: February 2025  
**Project**: Habitto iOS Habit Tracking App  
**Platform**: iOS 15.0+  
**Language**: Swift / SwiftUI

---

## 📁 Root Directory Structure

```
Habitto/
├── App/                          # Application entry point
├── Assets/                       # Visual assets and resources
├── Config/                       # Configuration files
├── Core/                         # Core application logic
├── Views/                        # SwiftUI views and screens
├── Tests/                        # Test files
├── Docs/                         # Documentation
├── Scripts/                      # Utility scripts
├── website/                      # Website-related files
└── [Configuration Files]         # Project configuration
```

---

## 🚀 App/

**Purpose**: Contains the main application entry point and Firebase initialization.

```
App/
├── HabittoApp.swift              # Main app entry point with SwiftUI App protocol
└── AppFirebase.swift             # Firebase configuration and initialization
```

**Key Files**:
- `HabittoApp.swift`: App lifecycle, dependency injection setup, and view hierarchy
- `AppFirebase.swift`: Firebase services initialization and configuration

---

## 🎨 Assets/

**Purpose**: Contains all visual assets including icons, colors, images, animations, and stickers used throughout the app.

```
Assets/
├── Animations/
│   └── SplashAnimation.json      # Lottie animation for splash screen
├── Colors.xcassets/              # Color asset catalog (64 color sets)
│   └── [Color variants: yellow, green, red, navy, pastelBlue, grey, etc.]
├── Icons.xcassets/               # Icon asset catalog
│   ├── BrandLogos/               # App brand logos (3 files)
│   ├── Icons_Colored/            # Colored icon variants (9 files)
│   ├── Icons_Filled/             # Filled icon style (71 files)
│   ├── Icons_Outlined/           # Outlined icon style (27 files)
│   └── IconsBottomNav/           # Bottom navigation icons (17 files)
├── Images.xcassets/              # Image assets
│   ├── blueGradient.imageset/
│   ├── Light-Gradient-BG-lighter@4x.imageset/
│   ├── Light-gradient-BG@4x.imageset/
│   ├── LightLightBlueGradient@4x.imageset/
│   ├── secondaryBlueGradient@4x.imageset/
│   └── splash1.imageset/
├── LightThemeColors.xcassets/    # Light theme color definitions (38 files)
└── Stickers.xcassets/            # Sticker/emoji assets
    ├── Difficulty/               # Difficulty level stickers (11 files)
    ├── EmptyState/               # Empty state illustrations (7 files)
    ├── Excitement/               # Excitement emojis (3 files)
    ├── Hanging.imageset/         # Hanging decoration
    ├── Profile/                  # Profile avatar stickers (75 files)
    ├── Time/                     # Time-related icons (11 files)
    └── Tutorial/                 # Tutorial illustrations (9 files)
```

**Usage**: Assets are accessed via SwiftUI `Image()` and `Color()` initializers using asset names.

---

## ⚙️ Config/

**Purpose**: Contains application configuration files, environment settings, and remote configuration.

```
Config/
├── App-Info.plist                # Application info and metadata
├── Env.swift                     # Environment variables and configuration
├── remote_config.json            # Firebase Remote Config values
└── RemoteConfigDefaults.plist    # Default Remote Config values
```

**Key Files**:
- `Env.swift`: Environment-specific configuration (dev/staging/prod)
- `remote_config.json`: Remote configuration schema

---

## 🏗️ Core/

**Purpose**: Contains the core application logic, business rules, data management, UI components, and services. This is the heart of the application.

### Core/Analytics/

**Purpose**: Analytics, performance monitoring, and privacy tracking.

```
Core/Analytics/
├── DataUsageAnalytics.swift      # Track data storage patterns
├── PerformanceMetrics.swift      # Performance monitoring and metrics
├── PrivacyHelper.swift           # Privacy compliance helpers
└── UserAnalytics.swift           # User behavior analytics
```

### Core/Config/

**Purpose**: Application configuration and feature flags.

```
Core/Config/
├── FirebaseBootstrapper.swift    # Firebase initialization logic
└── MigrationFeatureFlags.swift   # Feature flags for migrations
```

### Core/Constants/

**Purpose**: App-wide constants and static data.

```
Core/Constants/
├── EmojiData.swift               # Emoji data and mappings
└── ScheduleOptions.swift         # Schedule option definitions
```

### Core/Data/

**Purpose**: Data management, persistence, repositories, migrations, and storage implementations.

```
Core/Data/
├── BackgroundQueueManager.swift  # Background task queue management
├── Backup/                       # Backup system (2 files)
├── Cache/                        # Caching system (1 file)
├── CacheManager.swift            # Cache management
├── CalendarGridViews.swift       # Calendar grid UI components
├── CloudKitManager.swift         # CloudKit manager
├── Factory/                      # Factory pattern implementations (1 file)
│   └── StorageFactory.swift
├── Firestore/                    # Firestore integration (1 file)
├── GDPRDataDeletionManager.swift # GDPR data deletion
├── HabitRepository.swift         # Main habit repository (primary)
├── Migration/                    # Data migration system (14 files)
│   ├── DataMigrationManager.swift
│   ├── MigrationService.swift
│   ├── StorageMigrations.swift
│   └── DataFormatMigrations.swift
├── OptimizedHabitStorageManager.swift # Optimized storage manager
├── Protocols/                    # Data access protocols (1 file)
│   └── DataStorageProtocol.swift
├── Repositories/                 # Repository implementations (4 files)
├── Repository/                   # Repository pattern (2 files)
│   └── HabitRepositoryImpl.swift
├── RepositoryProvider.swift      # Repository provider
├── Retention/                    # Data retention policies (2 files)
├── SchemaVersion.swift           # Data schema versioning
├── Storage/                      # Storage implementations (9 files)
│   ├── UserDefaultsStorage.swift # Primary storage (active)
│   └── CoreDataStorage.swift     # Future storage (disabled)
├── StreakDataCalculator.swift    # Streak calculation logic
├── StreakViewComponents.swift    # Streak UI components
├── SwiftData/                    # SwiftData models and management (10 files)
└── Sync/                         # Data synchronization (1 file)
```

**Key Components**:
- **Repository Pattern**: Clean data access abstraction
- **Storage Implementations**: Multiple storage backends (UserDefaults, CoreData, SwiftData)
- **Migration System**: Seamless data format migrations
- **CloudKit/Firestore**: Cloud sync capabilities

### Core/Debug/

**Purpose**: Debug utilities and diagnostic tools.

```
Core/Debug/
└── HabitInvestigator.swift       # Habit data investigation tool
```

### Core/ErrorHandling/

**Purpose**: Error definitions and error handling logic.

```
Core/ErrorHandling/
├── DataError.swift               # Data-related error definitions
└── FirestoreError.swift          # Firestore-specific errors
```

### Core/Extensions/

**Purpose**: Swift extensions for built-in types.

```
Core/Extensions/
├── DateExtensions.swift          # Date utility extensions
└── ViewExtensions.swift          # SwiftUI view extensions
```

### Core/Managers/

**Purpose**: Manager classes that coordinate various app features and services.

```
Core/Managers/
├── AchievementManager.swift      # Achievement system management
├── AppRatingManager.swift        # App Store rating prompts
├── AuthenticationManager.swift   # User authentication (Google Sign-In, Guest)
├── AuthRoutingManager.swift      # Authentication routing logic
├── CompletionStateManager.swift  # Habit completion state management
├── EnhancedMigrationTelemetryManager.swift # Migration telemetry
├── I18nPreferences.swift         # Internationalization preferences
├── ICloudStatusManager.swift     # iCloud status monitoring
├── KeychainManager.swift         # Secure keychain access
├── MigrationTelemetryManager.swift # Migration tracking
├── NotificationManager.swift     # Local notification management
├── PermissionManager.swift       # iOS permission handling
├── SubscriptionManager.swift     # In-app purchase subscriptions
├── VacationManager.swift         # Vacation mode management
├── XPDataMigration.swift         # XP data migration
└── XPManager.swift               # XP and leveling system
```

### Core/Migration/

**Purpose**: Sample data generation and migration utilities.

```
Core/Migration/
└── SampleDataGenerator.swift     # Test data generation
```

### Core/Models/

**Purpose**: Data models and domain entities (30 files).

```
Core/Models/
└── [30 Swift model files]
    └── Habit.swift               # Core Habit model
```

**Key Models**:
- `Habit`: Main habit entity
- Completion records, XP records, vacation periods, etc.

### Core/Security/

**Purpose**: Security-related utilities and implementations.

```
Core/Security/
└── [1 security file]
```

### Core/Services/

**Purpose**: Service layer implementations for various app features.

```
Core/Services/
├── AccountDeletionService.swift  # User account deletion
├── BackupNotificationService.swift # Backup notifications
├── BackupScheduler.swift         # Backup scheduling
├── BackupSettingsManager.swift   # Backup settings
├── BackupStorageCoordinator.swift # Backup coordination
├── BackupTestingSuite.swift      # Backup testing
├── CloudStorageManager.swift     # Cloud storage management
├── CompletionService.swift       # Completion tracking service
├── CrashlyticsService.swift      # Crash reporting
├── DailyAwardService.swift       # Daily XP awards
├── DataValidationService.swift   # Data validation
├── EventBus.swift                # Event bus for pub/sub
├── EventCompactor.swift          # Event compression
├── FirebaseBackupService.swift   # Firebase backup
├── FirestoreService.swift        # Firestore operations
├── GoalMigrationService.swift    # Goal migration
├── GoalVersioningService.swift   # Goal version management
├── GoldenTestRunner.swift        # Golden test execution
├── GoogleDriveManager.swift      # Google Drive integration
├── HabitTrackingBridge.swift     # Habit tracking bridge
├── MigrationRunner.swift         # Migration execution
├── MigrationService.swift        # Migration orchestration
├── ProgressEventService.swift    # Progress event tracking
├── ProveItTestScenarios.swift    # Test scenarios
├── RemoteConfigService.swift     # Remote configuration
├── SyncHealthMonitor.swift       # Sync health monitoring
└── TelemetryService.swift        # Telemetry collection
```

### Core/Streaks/

**Purpose**: Streak calculation and management logic.

```
Core/Streaks/
└── [2 streak-related files]
```

### Core/Telemetry/

**Purpose**: Telemetry and analytics collection.

```
Core/Telemetry/
└── [1 telemetry file]
```

### Core/Time/

**Purpose**: Time and date utilities.

```
Core/Time/
└── [3 time-related files]
```

### Core/UI/

**Purpose**: Reusable UI components, design system, and UI building blocks.

```
Core/UI/
├── Animations/
│   └── ViewAnimatorStyle.swift   # Animation styles
├── BottomSheets/                 # Bottom sheet components (15 files)
│   ├── BaseBottomSheet.swift
│   ├── BottomSheetManager.swift
│   ├── ColorBottomSheet.swift
│   ├── IconBottomSheet.swift
│   ├── ScheduleBottomSheet.swift
│   ├── TutorialBottomSheet.swift
│   └── [Other bottom sheets]
├── Buttons/                      # Button system (4 files)
│   ├── ButtonSize.swift
│   ├── ButtonState.swift
│   ├── ButtonStyle.swift
│   └── ButtonSystem.swift
├── Cards/                        # Card components (3 files)
│   ├── GoalAchievementCard.swift
│   ├── HabitProgressCard.swift
│   └── InsightCard.swift
├── Common/                       # Common UI components (6 files)
│   ├── EmptyStateView.swift
│   ├── HabitIconView.swift
│   ├── HeaderView.swift
│   └── WhiteSheetContainer.swift
├── Components/                   # Reusable components (33 files)
│   ├── AnimatedCheckbox.swift
│   ├── CelebrationView.swift
│   ├── ExpandableCalendar.swift
│   ├── HabitEmptyStateView.swift
│   ├── ProgressChartComponents.swift
│   ├── XPDisplayView.swift
│   └── [Other components]
├── Forms/                        # Form components (14 files)
│   ├── EmojiKeyboardView.swift
│   ├── HabitFormComponents.swift
│   ├── HabitFormLogic.swift
│   └── ValidationBusinessRulesLogic.swift
├── Helpers/                      # UI helper utilities (7 files)
│   ├── HabitPatternAnalyzer.swift
│   ├── ProgressCalculationHelper.swift
│   └── ProgressViewComponentsHelper.swift
├── Items/                        # List item components (2 files)
│   ├── AddedHabitItem.swift
│   └── ScheduledHabitItem.swift
├── Keyboard/                     # Keyboard handling (1 file)
│   └── KeyboardAnchor.swift
├── Navigation/                   # Navigation components (3 files)
│   ├── TabBarView.swift
│   ├── TabMenu.swift
│   └── TabSystem.swift
└── Selection/                    # Selection components (6 files)
    ├── DatePickerModal.swift
    ├── MonthPickerModal.swift
    └── YearPickerModal.swift
```

**Key UI Categories**:
- **BottomSheets**: Modal bottom sheet implementations
- **Buttons**: Button design system
- **Components**: Reusable UI building blocks
- **Forms**: Form input and validation
- **Navigation**: Tab bar and navigation system

### Core/Utilities/

**Purpose**: General utility functions.

```
Core/Utilities/
└── [1 utility file]
```

### Core/Utils/

**Purpose**: Additional utility functions and helpers (21 files).

### Core/Validation/

**Purpose**: Data validation logic.

```
Core/Validation/
├── DataValidation.swift          # Data validation rules
└── DataIntegrityChecker.swift    # Data integrity checks
```

---

## 🖼️ Views/

**Purpose**: SwiftUI views organized by screen type and purpose.

```
Views/
├── Components/                   # View-level components (2 files)
├── Debug/                        # Debug views (5 files)
├── Flows/                        # Multi-step flow views (4 files)
│   ├── CreateHabitFlowView.swift
│   ├── CreateHabitStep1View.swift
│   └── CreateHabitStep2View.swift
├── LottieSplashView.swift        # Splash screen animation
├── Modals/                       # Modal views (5 files)
│   └── NotificationView.swift
├── Screens/                      # Main screen views (41 files)
│   ├── AboutUsView.swift
│   ├── AccountView.swift
│   ├── AchievementsView.swift
│   ├── HabitDetailView.swift
│   ├── HabitEditView.swift
│   ├── HomeView.swift
│   ├── OverviewView.swift
│   ├── ProfileView.swift
│   ├── SubscriptionView.swift
│   └── [Other screen views]
│   └── ViewModels/              # View models for screens
│       ├── HabitEditFormState.swift
│       └── HabitEditSession.swift
├── Settings/                     # Settings views (2 files)
└── Tabs/                         # Tab view implementations (4 files)
    ├── HomeTabView.swift
    ├── HabitsTabView.swift
    ├── ProgressTabView.swift
    └── MoreTabView.swift
```

**Key View Categories**:
- **Screens**: Full-screen views for major app features
- **Tabs**: Tab bar screen implementations
- **Flows**: Multi-step workflows (e.g., habit creation)
- **Modals**: Overlay and modal presentations
- **Settings**: Settings and preferences screens

---

## 🧪 Tests/

**Purpose**: Test files including unit tests, integration tests, and test data.

```
Tests/
├── firestore.rules.test.js       # Firestore security rules tests
├── GoldenScenarios/              # Golden test scenarios (6 files)
│   ├── [5 JSON test data files]
│   └── [1 markdown documentation]
└── Migration/                    # Migration tests (2 files)
    └── [Swift test files]
```

**Test Coverage**:
- Firestore security rules validation
- Data migration scenarios
- Golden scenario testing

---

## 📚 Docs/

**Purpose**: Comprehensive project documentation organized by category.

```
Docs/
├── Architecture/                 # Architecture documentation (8 files)
│   ├── ARCHITECTURE_OVERVIEW.md
│   ├── BACKUP_ARCHITECTURE.md
│   ├── DATA_ARCHITECTURE.md
│   ├── FIREBASE_ARCHITECTURE.md
│   └── DATA_SECURITY_GUIDELINES.md
├── data/                         # Data layer documentation (10 files)
│   ├── er_diagram.md
│   ├── model_inventory.md
│   ├── schema_snapshot_phase4.md
│   └── benchmarks/
│       └── streak_lookup.md
├── Features/                     # Feature documentation (6 files)
│   ├── FEATURE_FLAGS_README.md
│   ├── VIEWANIMATOR_INTEGRATION.md
│   └── ANIMATIONS_ADDED.md
└── Guides/                      # Development guides (1 file)
    └── FIREBASE_SETUP_GUIDE.md
```

---

## 🔧 Scripts/

**Purpose**: Utility scripts for development, testing, and automation.

```
Scripts/
├── analyze_logs.sh               # Log analysis script
├── capture_logs.sh               # Log capture script
├── python/                       # Python scripts (if any)
└── shell/                        # Shell utility scripts
```

---

## 🌐 website/

**Purpose**: Website-related files and deployment guides.

```
website/
└── DEPLOYMENT_GUIDE.md           # Website deployment instructions
```

---

## 📄 Root Configuration Files

**Purpose**: Project configuration, build settings, and deployment files.

```
[Root Directory]
├── README.md                     # Main project README
├── APP_OVERVIEW.md               # Comprehensive app overview
├── CHANGELOG.md                  # Version changelog
├── FOLDER_STRUCTURE.md           # This file
├── firebase.json                 # Firebase configuration
├── firestore.rules               # Firestore security rules
├── firestore.indexes.json        # Firestore indexes
├── package.json                  # Node.js dependencies
├── GoogleService-Info.plist      # Firebase configuration
├── Habitto.entitlements          # App entitlements
├── HabittoRelease.entitlements   # Release entitlements
├── PrivacyInfo.xcprivacy         # Privacy manifest
├── Habitto.xcodeproj/            # Xcode project file
├── HabittoPremium.storekit       # StoreKit configuration
├── LaunchScreen.storyboard       # Launch screen
└── [Other configuration files]
```

---

## 📊 Architecture Overview

### Directory Organization Principles

1. **Separation of Concerns**: 
   - `Core/` contains business logic
   - `Views/` contains UI components
   - `Assets/` contains resources

2. **Feature-Based Organization**:
   - Related files grouped together (e.g., `Core/Managers/`, `Core/Services/`)
   - Screens organized by function in `Views/Screens/`

3. **Layered Architecture**:
   - **UI Layer**: `Views/` and `Core/UI/`
   - **Business Logic**: `Core/Managers/` and `Core/Services/`
   - **Data Layer**: `Core/Data/` and `Core/Models/`
   - **Utilities**: `Core/Utils/` and `Core/Utilities/`

4. **Documentation**:
   - Comprehensive docs in `Docs/` directory
   - Architecture decisions documented
   - Guides for common tasks

### Key Design Patterns

- **Repository Pattern**: Data access abstraction in `Core/Data/`
- **Manager Pattern**: Feature coordination in `Core/Managers/`
- **Service Pattern**: Business logic services in `Core/Services/`
- **Factory Pattern**: Object creation in `Core/Data/Factory/`
- **Protocol-Based Design**: Interchangeable implementations

---

## 🔍 Quick Reference

### Where to Find Common Items

| Item | Location |
|------|----------|
| **App Entry Point** | `App/HabittoApp.swift` |
| **Main Views** | `Views/Tabs/` |
| **Habit Model** | `Core/Models/Habit.swift` |
| **Data Access** | `Core/Data/HabitRepository.swift` |
| **UI Components** | `Core/UI/Components/` |
| **Managers** | `Core/Managers/` |
| **Services** | `Core/Services/` |
| **Assets** | `Assets/` |
| **Configuration** | `Config/` |
| **Tests** | `Tests/` |
| **Documentation** | `Docs/` |

### File Naming Conventions

- **Views**: `*View.swift` (e.g., `HomeView.swift`)
- **Managers**: `*Manager.swift` (e.g., `XPManager.swift`)
- **Services**: `*Service.swift` (e.g., `CompletionService.swift`)
- **Models**: `*.swift` (singular nouns, e.g., `Habit.swift`)
- **Components**: `*Component.swift` or descriptive names
- **Extensions**: `*Extensions.swift` (e.g., `DateExtensions.swift`)

---

## 📝 Notes

- This structure follows iOS development best practices
- The project uses SwiftUI for UI and SwiftData for persistence
- Firebase integration is included for cloud features
- The architecture supports both local-first and cloud-synced data
- Migration system handles data format changes seamlessly

---

**For more detailed information about specific areas, refer to:**
- `README.md` - General project overview
- `APP_OVERVIEW.md` - Comprehensive app functionality
- `Docs/Architecture/` - Architecture documentation
- `Docs/Guides/` - Development guides

