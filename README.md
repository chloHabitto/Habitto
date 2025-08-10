# Habitto - Habit Tracking App

A comprehensive habit tracking application built with SwiftUI and Core Data.

## 📁 Project Structure

The project has been reorganized for better maintainability and clarity. Here's the current structure:

### 🚀 App
```
App/
└── HabittoApp.swift         # Main app entry point
```

### 🏗️ Core Architecture
```
Core/
├── Data/                    # Data management and persistence
│   ├── CoreDataManager.swift
│   ├── CoreDataAdapter.swift
│   ├── CloudKitManager.swift
│   └── HabittoDataModel.xcdatamodeld/
├── Models/                  # Data models
│   └── Habit.swift
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
│   ├── StreakView.swift
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
├── CORE_DATA_IMPLEMENTATION.md
├── HABIT_EDITING_SUMMARY.md
└── PROJECT_STRUCTURE.md     # Detailed project structure documentation
```

### 🧪 Tests
```
Tests/
├── HabitEditTest.swift
└── TestHabitEdit.swift
```

## Key Benefits of Current Structure

1. **Clear Separation of Concerns**: Core functionality is separated from UI presentation
2. **Logical Grouping**: Related components are grouped together by functionality
3. **Easier Navigation**: Developers can quickly find relevant files
4. **Better Maintainability**: Changes to specific areas are isolated
5. **Scalability**: New features can be added without cluttering existing structure
6. **iOS Best Practices**: Follows standard iOS development patterns

## Usage Guidelines

- **Core/UI**: Place reusable UI components here
- **Views**: Place screen-specific views here
- **Core/Data**: Place data management code here
- **Utils**: Place utility functions and helpers here
- **Assets**: Use `Image("Icon-name")` for icons and `Color("colorName")` for colors

## Migration Notes

- All existing functionality has been preserved
- No breaking changes to the app's design or behavior
- Import statements remain valid
- Build process unchanged
- Better organization for future development

This structure follows iOS development best practices and makes the codebase more maintainable for future development.
