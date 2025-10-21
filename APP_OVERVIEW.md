# Habitto App - Complete Overview & Instructions

## What is Habitto?

Habitto is a comprehensive iOS habit tracking application that helps users build positive habits and break negative ones through daily tracking, gamification, and smart scheduling. The app combines modern SwiftUI design with powerful data management to provide a seamless experience for personal growth and habit management.

---

## Core Concepts

### 1. **Habits**
A habit in Habitto represents any behavior you want to track. There are two types:

#### **Habit Formation** (Building Good Habits)
- Examples: Exercise 3 times per week, meditate daily, read 30 minutes
- Track progress toward completion goals
- User marks progress when they complete the habit
- Goal can be time-based, count-based, or simple completion

#### **Habit Breaking** (Reducing Bad Habits)
- Examples: Reduce smoking from 10 to 5 cigarettes, limit social media to 30 minutes
- Track actual usage vs. target reduction
- Helps visualize progress toward reducing unwanted behaviors
- Completed when usage stays at or below target

### 2. **Schedules**
Every habit has a schedule that determines when it should be tracked:

- **Every Day**: Habit appears every single day
- **Weekdays**: Monday through Friday only
- **Weekends**: Saturday and Sunday only
- **Specific Days**: Choose any combination (e.g., Monday, Wednesday, Friday)
- **Frequency-Based**: 
  - "X times per week" (e.g., "3 times per week")
  - "X days a month" (e.g., "5 days a month")
- **Interval-Based**: Every X days (e.g., "Every 3 days")

### 3. **Progress Tracking**
- Each habit tracks daily completion status
- For formation habits: increment progress (e.g., 0/3 → 1/3 → 2/3 → 3/3)
- For breaking habits: log actual usage and compare to target
- Historical data is preserved with timestamps
- Difficulty can be rated after completion (1-10 scale)

### 4. **Streaks**
- A streak measures consecutive days of completion
- Calculated automatically based on completion history
- Vacation days don't break streaks (see Vacation Mode)
- "Best streak" shows your longest consecutive completion period
- Streaks reset when a scheduled habit day is missed

### 5. **XP & Leveling System**
- **XP (Experience Points)**: Earned for completing all habits on a given day
- **Level**: Calculated from total XP earned
- **Daily Completion Bonus**: 50 XP when all habits for the day are completed
- **Level Calculation**: Higher levels require more XP (quadratic progression)
- **Visual Feedback**: Celebration animation when all habits are completed

---

## How the App Works

### App Startup
1. **Launch Screen**: Animated Lottie splash screen
2. **Authentication**: 
   - Guest mode (local data only)
   - Sign in with Google (data syncs with user account)
3. **Data Loading**: 
   - Habits loaded from SwiftData (local database)
   - XP calculated from completion records
   - Notifications rescheduled for active habits

### Main Interface

#### **Home Tab** (Main View)
The home screen shows:
- **Calendar Picker**: Expandable calendar to select any date
- **Habit List**: All habits scheduled for the selected date
  - Incomplete habits appear first
  - Completed habits move to bottom (greyed out)
  - Progress indicators show completion status
- **Quick Actions**:
  - Tap checkbox to mark complete
  - Tap habit card to view details
  - Swipe actions for edit/delete

#### **Stats Display**
- Total habits for the day
- Undone count
- Done count
- Visual progress indicator

#### **Celebration Flow**
When you complete the LAST habit of the day:
1. Difficulty rating sheet appears (1-10 scale)
2. After rating, celebration animation plays
3. XP is awarded (50 points)
4. Progress is saved to history

### Creating a Habit

#### **Step 1: Basic Information**
- **Name**: What is this habit? (e.g., "Morning Run")
- **Description**: Why does it matter? (e.g., "Build cardiovascular fitness")
- **Icon**: Visual representation from icon library
- **Color**: Custom color for visual identification
- **Type**: Formation (building) or Breaking (reducing)

#### **Step 2: Schedule & Goals**
- **Schedule**: When should this habit be tracked?
  - Choose from preset patterns
  - Or create custom schedules
- **Goal**: What's the target?
  - Formation: "3 times per day", "30 minutes", "1 time"
  - Breaking: Baseline usage → Target usage (e.g., 10 → 5)
- **Start Date**: When does tracking begin?
- **End Date** (optional): When should tracking stop?

#### **Step 3: Reminders**
- Add multiple reminder times
- Set custom messages per reminder
- Enable/disable individual reminders
- Snooze options (10 min, 15 min, 30 min)

### Tracking Progress

#### **Marking a Habit Complete**
1. **Quick Toggle**: Tap the checkbox on habit card
2. **Difficulty Rating**: After completion, rate how difficult it was (1-10)
3. **Progress Update**: Visual feedback shows completion
4. **XP Check**: If all habits complete, earn 50 XP bonus

#### **Partial Progress** (Formation Habits)
- Tap the progress indicator to increment
- Example: "2 out of 3 times" → tap to make it "3 out of 3 times"
- Habit considered complete only when goal is fully met

#### **Usage Logging** (Breaking Habits)
- Enter actual usage amount
- System compares to target
- Complete if usage ≤ target
- Visual indicator shows progress toward target

### Habit Details View

Access by tapping any habit card. Shows:
- **Current Progress**: Today's completion status
- **Streak Information**: Current and best streaks
- **Calendar Grid**: Historical completion view (month/year)
- **Statistics**:
  - Total completions
  - Success rate
  - Average difficulty
  - Completion patterns
- **Edit Button**: Modify habit settings
- **Delete Option**: Remove habit permanently

### Vacation Mode

Take a break without breaking your streaks!

#### **What is Vacation Mode?**
- Temporarily pauses habit tracking
- Vacation days don't count toward or against streaks
- All habits are hidden during vacation
- Notifications are muted

#### **How to Use**
1. Enable vacation mode from settings
2. Choose start date (today or tomorrow)
3. System tracks vacation period
4. End vacation manually when you return
5. Habits and notifications resume immediately

#### **Vacation Day Behavior**
- Streak calculations skip vacation days
- Historical data preserved (marked as vacation)
- Calendar shows vacation indicator
- Can end vacation early for specific dates

---

## Data & Persistence

### **Local Storage**
All data is stored locally on your device using:
- **SwiftData**: Primary database for habits and completion records
- **UserDefaults**: User preferences and cached calculations
- **Keychain**: Secure storage for authentication tokens

### **Data Types Stored**
- **Habits**: Name, schedule, goals, settings, creation date
- **Completion Records**: Date, progress amount, timestamps, difficulty
- **XP Records**: Daily awards, total XP, level progression
- **User Settings**: Preferences, theme, notification settings
- **Vacation Periods**: Start/end dates, vacation history

### **Authentication & Cloud Sync**
- **Guest Mode**: All data stays on device
- **Authenticated Mode** (Google Sign-In):
  - Habits associated with user account
  - Data can be synced across devices (optional)
  - XP and progress tied to user ID
  - Migration from guest to authenticated preserves data

### **Data Migration**
The app handles several migration scenarios:
- Guest data → Authenticated user data
- Old storage format → New repository pattern
- Completion history format updates
- XP system updates

---

## Advanced Features

### **Schedule Intelligence**

#### **Dynamic Habit Instances**
For "X times per week" schedules:
- App creates virtual instances of the habit
- Instances slide forward if missed
- Flexible completion within the week
- Prevents overwhelming the user with overdue tasks

#### **Monthly Frequency**
For "X days a month" schedules:
- Distributes remaining completions across remaining days
- Adapts as month progresses
- Example: "5 days a month" on Oct 28 → shows for 4 days (if 1 already done)

### **Smart Notifications**

#### **Reminder System**
- Multiple reminders per habit
- Custom messages per reminder
- Time-based triggers
- Snooze functionality (10/15/30 minutes)
- Batch notification management

#### **Notification Actions**
From notification:
- Snooze for 10, 15, or 30 minutes
- Dismiss
- Open app to specific habit

### **XP & Gamification**

#### **XP Calculation**
```
Daily XP = 50 XP (when all habits completed for the day)
Level = √(totalXP / 300) + 1
```

#### **Level Progression**
- Level 1: 0 XP
- Level 2: 300 XP
- Level 3: 1,200 XP
- Level 4: 2,700 XP
- And so on (quadratic progression)

#### **XP Rules**
- Only awarded when ALL habits for the day are complete
- One bonus per day maximum
- Based on completion, not individual habit XP
- Historical XP calculated from completion records
- Retroactive XP for past complete days

### **Streak Calculations**

#### **Current Streak**
```swift
Start from today
Count backward consecutive complete days
Stop at first incomplete day (excluding vacation)
Streak = number of consecutive days
```

#### **Best Streak**
```swift
Scan entire history from habit start to today
Find longest consecutive completion sequence
Exclude vacation days from breaking streaks
Best Streak = maximum consecutive days found
```

#### **Vacation Handling**
- Active vacation days: neutral (don't count, don't break)
- Historical vacation days: preserved in history
- Streak continues across vacation periods

---

## User Interface Components

### **Core UI Elements**

#### **Expandable Calendar**
- Week view by default
- Tap to expand to month view
- Swipe to navigate weeks/months
- Haptic feedback on interactions
- Today indicator
- Selected date highlighting

#### **Habit Cards**
- Icon and color coding
- Progress indicators
- Completion checkbox
- Difficulty rating (after completion)
- Streak badge
- Schedule information

#### **Bottom Sheets**
- Difficulty rating (1-10 scale)
- Habit details
- Edit forms
- Confirmation dialogs

#### **Celebration Animation**
- Lottie animation for XP rewards
- Confetti effect
- Sound effect (optional)
- XP amount display
- Level up notification

### **Visual Design**

#### **Color System**
- Primary: App branding colors
- Habit colors: User-customizable per habit
- Success: Green for completions
- Error: Red for warnings/errors
- Neutral: Grey for inactive states

#### **Typography**
- System fonts with custom weights
- Scalable text (accessibility)
- Consistent hierarchy
- Monospace for numbers/stats

#### **Animations**
- Smooth transitions between views
- Haptic feedback for interactions
- Progress bar animations
- Celebration effects
- Swipe gestures

---

## Architecture & Technical Design

### **App Architecture**

```
┌─────────────────────────────────────────────┐
│          SwiftUI Views Layer                │
│  HomeTabView, HabitDetailView, etc.         │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│       Repository Layer (@MainActor)          │
│  HabitRepository - UI-facing facade          │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│         Actor Layer (Thread-safe)            │
│  HabitStore - Actual data operations         │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│        Persistence Layer                     │
│  SwiftData, UserDefaults, Keychain           │
└─────────────────────────────────────────────┘
```

### **Key Managers**

#### **HabitRepository**
- Main data coordinator for UI
- `@MainActor` for UI safety
- Published properties for SwiftUI
- Manages habit CRUD operations
- Coordinates XP awards

#### **HabitStore** (Actor)
- Thread-safe data operations
- SwiftData interactions
- Completion record management
- Data validation
- Migration handling

#### **XPManager**
- `@Observable` for SwiftUI reactivity
- Calculates XP from completion days
- Level progression
- Transaction history
- User progress tracking

#### **VacationManager**
- Tracks active vacation periods
- Historical vacation records
- Notification muting
- Streak preservation logic

#### **NotificationManager**
- Schedules local notifications
- Reminder management
- Snooze handling
- Category configuration

#### **AuthenticationManager**
- Google Sign-In integration
- User session management
- Guest mode support
- Data migration triggers

### **Data Models**

#### **Habit**
```swift
struct Habit {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let color: CodableColor
    let habitType: HabitType // formation or breaking
    let schedule: String
    let goal: String
    let startDate: Date
    let endDate: Date?
    var completionHistory: [String: Int]
    var completionStatus: [String: Bool]
    var completionTimestamps: [String: [Date]]
    var difficultyHistory: [String: Int]
    var reminders: [ReminderItem]
    
    // Computed properties
    func isCompleted(for date: Date) -> Bool
    func calculateTrueStreak() -> Int
    func getProgress(for date: Date) -> Int
}
```

#### **CompletionRecord** (SwiftData)
```swift
@Model
class CompletionRecord {
    var id: UUID
    var habitId: UUID
    var userId: String
    var dateKey: String
    var progress: Int
    var isCompleted: Bool
    var timestamp: Date
}
```

#### **DailyAward** (SwiftData)
```swift
@Model
class DailyAward {
    var id: UUID
    var userId: String
    var dateKey: String
    var xpGranted: Int
    var allHabitsCompleted: Bool
    var grantedAt: Date
}
```

### **Concurrency Model**

#### **Swift 6 Concurrency**
- `@MainActor` for UI updates
- `actor` for thread-safe data access
- `async/await` for asynchronous operations
- Structured concurrency with Task

#### **Data Flow**
```
User Action (UI)
    ↓
Repository (@MainActor)
    ↓
Actor (Thread-safe)
    ↓
SwiftData/Storage
    ↓
Actor (Thread-safe)
    ↓
Repository (@MainActor)
    ↓
UI Update (Published property)
```

---

## Common User Flows

### **Daily Usage Flow**

1. **Morning**: User opens app
   - Sees today's habits
   - Habits sorted (incomplete first)
   - Reminders scheduled for the day

2. **Throughout Day**: User completes habits
   - Taps checkbox to mark complete
   - Rates difficulty (optional)
   - Progress updates immediately
   - Streak increments if on schedule

3. **Last Habit**: User completes final habit
   - Difficulty rating appears
   - User rates how hard it was (1-10)
   - Dismisses difficulty sheet
   - **Celebration animation plays** 🎉
   - 50 XP awarded
   - Total XP updates
   - Level may increase

4. **Next Day**: Cycle repeats
   - Previous day marked complete in history
   - New day's habits appear
   - Streaks continue

### **Habit Creation Flow**

1. **Tap Create Button** (+)
2. **Step 1: Basic Info**
   - Enter name and description
   - Choose icon and color
   - Select habit type
3. **Step 2: Schedule**
   - Choose when to track
   - Set completion goal
   - Define start/end dates
4. **Step 3: Reminders**
   - Add reminder times
   - Customize messages
   - Enable notifications
5. **Save**: Habit appears in list immediately

### **Vacation Mode Flow**

1. **Enable Vacation**
   - Open More tab
   - Select Vacation Mode
   - Choose start date (today or tomorrow)
   - Confirm

2. **During Vacation**
   - All habits hidden
   - No notifications sent
   - Streak preservation active
   - Can end early if needed

3. **End Vacation**
   - Manually end vacation
   - Or automatic end at set date
   - Habits reappear
   - Notifications resume
   - Streaks preserved

### **Data Migration Flow** (Guest → Authenticated)

1. **User Creates Habits** (as guest)
   - Data stored locally with empty userId
   
2. **User Signs In** (Google)
   - AuthenticationManager detects guest data
   - Migration system triggers
   
3. **Automatic Migration**
   - Guest habits reassigned to user ID
   - Completion records updated
   - XP recalculated for user
   - Data now synced to account

4. **Post-Migration**
   - All data preserved
   - User can sign out/in freely
   - Data follows their account

---

## Error Handling & Edge Cases

### **Missing Data**
- Graceful fallback to defaults
- Empty state messaging
- Recovery suggestions
- Debug logging for troubleshooting

### **Corrupt Data**
- Validation on load
- Automatic cleanup
- UserDefaults fallback
- Fresh start option (last resort)

### **Duplicate Habits**
- ID-based deduplication
- Automatic cleanup on load
- Prevents UI flickering

### **Stale Data**
- Force reload mechanisms
- Pull-to-refresh
- App lifecycle management
- Cache invalidation

### **Daylight Saving Time**
- Deterministic calendar usage
- Timezone-aware date handling
- Midnight transition handling
- Historical date preservation

### **Notification Limits**
- iOS limit: 64 pending notifications
- Smart scheduling prioritization
- Oldest notifications removed first
- Daily reminder consolidation

---

## Performance Optimizations

### **Data Loading**
- Lazy loading for large datasets
- Prefetched completion status
- Cached calculations
- Debounced saves (0.5s)

### **UI Rendering**
- LazyVStack for scrolling performance
- Cached regex patterns
- Minimized re-renders
- Computed properties cached when possible

### **Memory Management**
- Weak references where appropriate
- Automatic cleanup on sign-out
- Limited transaction history (10 recent)
- Periodic cache clearing

---

## Privacy & Security

### **Data Privacy**
- **Local-First**: All data stored on device by default
- **Optional Cloud**: User chooses to enable sync
- **No Analytics**: No user tracking or behavior monitoring
- **No Ads**: Completely ad-free experience

### **Data Classification**
- **Public**: App UI, icons, colors
- **User Data**: Habits, completions, preferences
- **Sensitive**: Authentication tokens (Keychain)

### **Security Measures**
- Keychain storage for tokens
- Secure authentication flows
- No plaintext password storage
- HTTPS for all network requests

---

## Accessibility

### **Visual**
- Dynamic Type support
- High contrast modes
- Color-blind friendly indicators
- Screen reader compatible

### **Motor**
- Large touch targets (44x44 pt minimum)
- Swipe gestures optional
- Voice Control support
- Haptic feedback

### **Cognitive**
- Clear visual hierarchy
- Consistent navigation
- Undo functionality
- Confirmation dialogs for destructive actions

---

## Troubleshooting

### **Common Issues**

#### **Habits Not Appearing**
1. Check selected date (might be past/future)
2. Verify habit schedule matches selected date
3. Try pull-to-refresh
4. Force reload from settings

#### **XP Not Updating**
1. Ensure ALL habits for the day are complete
2. Check if difficulty was rated
3. Verify not in vacation mode
4. Restart app if needed

#### **Notifications Not Working**
1. Check iOS Settings > Habitto > Notifications
2. Verify reminders are enabled for habit
3. Ensure not in Do Not Disturb mode
4. Check vacation mode status

#### **Data Missing After Sign-In**
1. Migration should be automatic
2. Check if data exists in guest mode (sign out)
3. Contact support if data truly lost
4. Check for recent backups (if enabled)

---

## Future Features (Planned)

### **In Development**
- CloudKit cross-device sync
- Advanced analytics and insights
- Habit templates library
- Social features (optional)
- AI-powered recommendations
- Custom themes

### **Under Consideration**
- Apple Watch companion app
- Widgets for iOS home screen
- Siri Shortcuts integration
- Export/import functionality
- Advanced statistics
- Habit dependencies

---

## For Developers

### **Getting Started**
1. Clone repository
2. Open `Habitto.xcodeproj`
3. Build and run (⌘+R)
4. All dependencies managed via Swift Package Manager

### **Key Files**
- `App/HabittoApp.swift`: App entry point
- `Core/Data/HabitRepository.swift`: Main data coordinator
- `Core/Models/Habit.swift`: Core habit model
- `Views/Tabs/HomeTabView.swift`: Main UI
- `Core/Managers/XPManager.swift`: XP system

### **Testing**
- Unit tests in `Tests/` directory
- Firebase emulator for backend testing
- Golden scenarios for data validation

### **Architecture Principles**
1. Repository pattern for data access
2. Protocol-based design for flexibility
3. Swift 6 concurrency for safety
4. SwiftUI for reactive UI
5. Local-first data approach

---

## Summary

**Habitto** is a powerful, privacy-focused habit tracking app that helps users build better habits through:

- ✅ **Flexible Scheduling**: Track habits daily, weekly, monthly, or custom patterns
- ✅ **Dual Habit Types**: Build good habits or break bad ones
- ✅ **Gamification**: XP, levels, and streaks keep you motivated
- ✅ **Vacation Mode**: Take breaks without losing progress
- ✅ **Smart Notifications**: Reminders when you need them
- ✅ **Beautiful UI**: Modern, intuitive SwiftUI design
- ✅ **Privacy-First**: Your data stays on your device
- ✅ **Offline-Capable**: No internet required
- ✅ **Data Persistence**: Never lose your progress
- ✅ **Multi-User Support**: Guest mode or authenticated accounts

The app is designed to be simple enough for daily use but powerful enough to handle complex habit tracking needs. Whether you're building a new fitness routine, learning a new skill, or breaking an unwanted behavior, Habitto provides the tools and motivation to succeed.

---

**Last Updated**: October 21, 2025  
**Version**: 1.0  
**Platform**: iOS 15.0+  
**Built With**: SwiftUI, SwiftData, Firebase, Swift 6

