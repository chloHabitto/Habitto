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
- **CloudKitManager.swift** - CloudKit integration
- **CoreDataAdapter.swift** - Core Data adapter layer
- **CoreDataManager.swift** - Core Data management
- **HabittoDataModel.xcdatamodeld/** - Core Data model

#### Core/Extensions
- **DateExtensions.swift** - Date utility extensions
- **ViewExtensions.swift** - SwiftUI view extensions

#### Core/Models
- **Habit.swift** - Core Habit model

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
- **Managers/** - Manager classes (notifications, etc.)
- **Scripts/** - Build and utility scripts

### 📚 Documentation
- **CORE_DATA_IMPLEMENTATION.md** - Core Data implementation details
- **HABIT_EDITING_SUMMARY.md** - Habit editing functionality

### 🧪 Tests
- **HabitEditTest.swift** - Habit editing tests
- **TestHabitEdit.swift** - Additional habit editing tests

## Key Benefits of Reorganization

1. **Clear Separation of Concerns**: Core functionality is separated from UI presentation
2. **Logical Grouping**: Related components are grouped together
3. **Easier Navigation**: Developers can quickly find relevant files
4. **Better Maintainability**: Changes to specific areas are isolated
5. **Scalability**: New features can be added without cluttering existing structure

## Migration Notes

- All existing import statements remain valid
- No functionality has been changed or removed
- File contents are identical to before reorganization
- Build process remains unchanged

## Best Practices

- **Core/UI**: Place reusable UI components here
- **Views**: Place screen-specific views here
- **Core/Data**: Place data management code here
- **Utils**: Place utility functions and helpers here

This structure follows iOS development best practices and makes the codebase more maintainable for future development.
