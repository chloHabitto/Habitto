# Habitto Project Structure

This document outlines the reorganized file structure for the Habitto iOS app.

## Overview

The project has been reorganized to improve maintainability, readability, and developer experience while preserving all existing functionality and design.

## Directory Structure

### 🚀 App
- **HabittoApp.swift** - Main app entry point

### 🎨 Assets
- **Colors.xcassets/** - Color definitions and themes
- **Icons.xcassets/** - App icons and UI elements

### 🏗️ Core
The core layer contains all fundamental app components:

#### Core/Constants
- **EmojiData.swift** - Emoji constants and data
- **ScheduleOptions.swift** - Schedule-related constants

#### Core/Data
- **HabitRepository.swift** - Main data coordinator and repository
- **HabitRepositoryNew.swift** - Repository facade
- **HabitRepositoryImpl.swift** - Repository implementation
- **CoreDataManager.swift** - Core Data management
- **CloudKitManager.swift** - CloudKit integration
- **Protocols/** - Data access protocols
  - **DataStorageProtocol.swift** - Storage abstraction
- **Storage/** - Storage implementations
  - **UserDefaultsStorage.swift** - Primary storage (active)
  - **CoreDataStorage.swift** - Future storage (disabled)
- **Repository/** - Repository implementations
  - **HabitRepositoryImpl.swift** - Concrete repository
- **Factory/** - Storage factory
  - **StorageFactory.swift** - Storage selection
- **Migration/** - Data migration system
  - **DataMigrationManager.swift** - Migration orchestration
  - **MigrationService.swift** - UI integration
  - **StorageMigrations.swift** - Storage type changes
  - **DataFormatMigrations.swift** - Data model changes
- **CloudKit/** - CloudKit integration
  - **CloudKitModels.swift** - CloudKit data models
  - **CloudKitSyncManager.swift** - Sync operations
  - **CloudKitSchema.swift** - Schema validation
  - **CloudKitConflictResolver.swift** - Conflict resolution
  - **CloudKitIntegrationService.swift** - Integration facade
- **Background/** - Background processing
  - **BackgroundQueueManager.swift** - Queue management

#### Core/Extensions
- **DateExtensions.swift** - Date utility extensions
- **ViewExtensions.swift** - SwiftUI view extensions

#### Core/Models
- **Habit.swift** - Core Habit model

#### Core/Validation
- **DataValidation.swift** - Data validation logic
- **DataIntegrityChecker.swift** - Data integrity monitoring
- **DataValidationService.swift** - Validation service facade

#### Core/ErrorHandling
- **DataError.swift** - Error types and handling

#### Core/Analytics
- **PerformanceMetrics.swift** - Performance monitoring
- **UserAnalytics.swift** - User behavior tracking
- **DataUsageAnalytics.swift** - Data usage analytics

#### Core/UI
Organized UI components by functionality:

- **BottomSheets/** - All bottom sheet components
- **Buttons/** - Button system and styles
- **Cards/** - Card-based UI components
- **Common/** - Shared UI components
- **Forms/** - Form-related components
- **Items/** - List item components
- **Navigation/** - Navigation components
- **Selection/** - Selection and picker components

### 📱 Views
User interface screens and flows:

- **Features/** - Feature-specific views
- **Flows/** - Multi-step user flows
- **Modals/** - Modal presentations
- **Screens/** - Main app screens
- **Shared/** - Shared view components
- **Tabs/** - Tab-based navigation

### 🛠️ Utils
Utility and helper functions:

- **Design/** - Design system utilities (colors, fonts, dates)
- **Date/** - Date utilities
  - **ISO8601DateHelper.swift** - ISO 8601 date formatting
  - **DateUtilities.swift** - Comprehensive date operations
- **Storage/** - Storage utilities
  - **UserDefaultsWrapper.swift** - Type-safe UserDefaults access
- **Managers/** - Manager classes (notifications, etc.)
- **Scripts/** - Build and utility scripts

### 📚 Documentation
- **ARCHITECTURE_OVERVIEW.md** - Comprehensive architecture overview
- **CORE_DATA_IMPLEMENTATION.md** - Core Data implementation details
- **FIREBASE_ARCHITECTURE.md** - Firebase usage and data architecture
- **HABIT_EDITING_SUMMARY.md** - Habit editing functionality
- **OPTIMIZED_STORAGE_IMPLEMENTATION.md** - UserDefaults optimization
- **DATA_SECURITY_GUIDELINES.md** - Security and privacy guidelines

### 🧪 Tests
- **HabitEditTest.swift** - Habit editing functionality tests
- **TestRunner.swift** - Comprehensive test runner
- **SimpleTestRunner.swift** - Alternative test runner

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
- ✅ All existing import statements remain valid
- ✅ No functionality has been changed or removed
- ✅ All UI and user experience preserved
- ✅ Build process remains unchanged
- ✅ Data migration is automatic and seamless

### **Future Migrations (Planned)**
- 🔄 **Core Data**: Migrate from UserDefaults to Core Data for better performance
- 🔄 **CloudKit Sync**: Enable cross-device synchronization
- 🔄 **Advanced Analytics**: Add AI-powered insights and recommendations

## Best Practices

- **Core/UI**: Place reusable UI components here
- **Views**: Place screen-specific views here
- **Core/Data**: Place data management code here
- **Utils**: Place utility functions and helpers here

This structure follows iOS development best practices and makes the codebase more maintainable for future development.
