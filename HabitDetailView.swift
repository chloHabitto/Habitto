import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct HabitDetailView: View {
    @State var habit: Habit
    let onUpdateHabit: ((Habit) -> Void)?
    let selectedDate: Date
    let onDeleteHabit: ((Habit) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var todayProgress: Int = 0
    @State private var showingEditView = false
    @State private var showingDeleteConfirmation = false
    @State private var showingReminderSheet = false
    @State private var selectedReminder: ReminderItem?
    @State private var scrollOffset: CGFloat = 0
    @State private var availableHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    // Computed property to determine if content should scroll
    private var shouldScroll: Bool {
        // Add some buffer to account for safe areas and ensure we detect when scrolling is needed
        let bufferHeight: CGFloat = 100 // Reduced buffer for easier detection
        
        // If content height is 0 (not measured yet), check if habit has many reminders as a fallback
        if contentHeight == 0 {
            let hasManyReminders = habit.reminders.count > 3
            print("🔍 SCROLL CHECK (FALLBACK) - Content not measured yet, Has many reminders: \(hasManyReminders), Should Scroll: \(hasManyReminders)")
            return hasManyReminders
        }
        
        let needsScrolling = contentHeight > (availableHeight - bufferHeight)
        print("🔍 SCROLL CHECK - Content: \(Int(contentHeight)), Available: \(Int(availableHeight)), Buffer: \(Int(bufferHeight)), Should Scroll: \(needsScrolling)")
        return needsScrolling
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background
                Color.surface2
                    .ignoresSafeArea()
                
                // Always show the content, but measure it first
                VStack {
                    // Sticky compact header (appears when scrolled)
                    compactHeader
                        .background(Color.surface2)
                        .opacity(shouldScroll && scrollOffset > 50 ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: shouldScroll && scrollOffset > 50)
                    
                    // Debug indicator (remove in production)
                    VStack {
                        Text("Content: \(Int(contentHeight)) | Available: \(Int(availableHeight)) | Should Scroll: \(shouldScroll)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(4)
                            .background(Color.yellow.opacity(0.8))
                            .cornerRadius(4)
                            .multilineTextAlignment(.center)
                        
                        if scrollOffset > 0 {
                            Text("Scroll Offset: \(Int(scrollOffset))")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(2)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                }
                .zIndex(1)
                
                // Content - measure and display
                ZStack {
                    // Hidden measurement view (positioned off-screen)
                    contentView
                        .opacity(0)
                        .position(x: -1000, y: -1000) // Move off-screen
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear
                                    .preference(key: ContentSizePreferenceKey.self, value: contentGeometry.size)
                            }
                        )
                        .onPreferenceChange(ContentSizePreferenceKey.self) { size in
                            let newHeight = size.height
                            if abs(newHeight - contentHeight) > 1 {
                                contentHeight = newHeight
                                print("🔍 CONTENT MEASURED - Height: \(Int(contentHeight)), Available: \(Int(availableHeight))")
                                print("🔍 SHOULD SCROLL CALCULATION - Content: \(Int(contentHeight)) > (Available: \(Int(availableHeight)) - Buffer: 150) = \(Int(contentHeight)) > \(Int(availableHeight - 150)) = \(contentHeight > (availableHeight - 150))")
                            }
                        }
                    
                    // Actual content display
                    if shouldScroll {
                        ScrollViewReader { proxy in
                            ScrollView {
                                contentView
                                    .background(
                                        GeometryReader { contentGeometry in
                                            Color.clear
                                                .preference(key: ScrollOffsetPreferenceKey.self, 
                                                          value: contentGeometry.frame(in: .global).minY)
                                        }
                                    )
                            }
                            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                                let newOffset = -value
                                if abs(newOffset - scrollOffset) > 1 {
                                    scrollOffset = newOffset
                                    print("🔍 Scroll offset: \(scrollOffset)")
                                }
                            }
                        }
                        .onAppear {
                            print("🔍 DISPLAY PHASE - Using ScrollView (Content: \(Int(contentHeight)), Available: \(Int(availableHeight)))")
                        }
                    } else {
                        VStack {
                            contentView
                            Spacer(minLength: 0)
                        }
                        .onAppear {
                            print("🔍 DISPLAY PHASE - Using Static VStack (Content: \(Int(contentHeight)), Available: \(Int(availableHeight)))")
                        }
                    }
                }
            }
            .onAppear {
                availableHeight = geometry.size.height
                todayProgress = habit.getProgress(for: selectedDate)
                print("🔍 SCREEN APPEARED - Available Height: \(Int(availableHeight))")
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                availableHeight = newHeight
                print("🔍 SCREEN HEIGHT CHANGED - New: \(Int(newHeight))")
            }
        }
        .navigationBarHidden(true)
        .onChange(of: selectedDate) { oldDate, newDate in
            // Only update progress if the date actually changed
            let calendar = Calendar.current
            let oldDay = calendar.startOfDay(for: oldDate)
            let newDay = calendar.startOfDay(for: newDate)
            
            if oldDay != newDay {
                todayProgress = habit.getProgress(for: selectedDate)
            }
        }
        .fullScreenCover(isPresented: $showingEditView) {
            HabitEditView(habit: habit, onSave: { updatedHabit in
                print("🔄 HabitDetailView: Habit updated - \(updatedHabit.name)")
                habit = updatedHabit
                onUpdateHabit?(updatedHabit)
                print("🔄 HabitDetailView: onUpdateHabit callback called")
            })
        }
        .sheet(isPresented: $showingReminderSheet) {
            ReminderEditSheet(
                habit: habit,
                reminder: selectedReminder,
                onSave: { updatedHabit in
                    habit = updatedHabit
                    onUpdateHabit?(updatedHabit)
                    selectedReminder = nil
                },
                onCancel: {
                    selectedReminder = nil
                }
            )
        }
        .alert("Delete Habit", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDeleteHabit?(habit)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this habit? This action cannot be undone.")
        }
    }
    
    // MARK: - Content View (shared between scrollable and static)
    private var contentView: some View {
        VStack(spacing: 0) {
            // Full header (fades out when scrolled)
            fullHeader
                .opacity(shouldScroll && scrollOffset > 50 ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: shouldScroll && scrollOffset > 50)
                .padding(.top, 0)
                .padding(.bottom, 24)
                .id("header")
            
            // Main content card
            mainContentCard
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
        }
    }
    
    // MARK: - Full Header (shown when at top)
    private var fullHeader: some View {
        VStack(spacing: 0) {
            // Top row with close button and menu
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                }
                
                Spacer()
                
                // More options button with menu
                Menu {
                    Button(action: {
                        showingEditView = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Title section - left aligned
            VStack(alignment: .leading, spacing: 8) {
                Text("Habit details")
                    .font(.appHeadlineSmallEmphasised)
                    .foregroundColor(.text01)
                    .accessibilityAddTraits(.isHeader)

                Text("View and edit your habit details.")
                    .font(.appTitleSmall)
                    .foregroundColor(.text05)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .padding(.top, 0)
    }
    
    // MARK: - Compact Header (shown when scrolled)
    private var compactHeader: some View {
        HStack {
            // Close button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.text01)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            
            // Title
            Text("Habit details")
                .font(.appHeadlineSmallEmphasised)
                .foregroundColor(.text01)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            // More options button with menu
            Menu {
                Button(action: {
                    showingEditView = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.text01)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .padding(.top, 8) // Safe area padding
        .background(Color.surface2)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Main Content Card
    private var mainContentCard: some View {
        VStack(spacing: 0) {
            // Habit Summary Section
            habitSummarySection
            
            Divider()
                .padding(.horizontal, 16)
            
            // Habit Details Section
            habitDetailsSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // Reminders Section
            remindersSection
            
            Divider()
                .padding(.horizontal, 16)
            
            // Today's Progress Section
            todayProgressSection
        }
        .background(.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Habit Summary Section
    private var habitSummarySection: some View {
        HStack(spacing: 12) {
            // Habit Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.surfaceContainer)
                    .frame(width: 48, height: 48)
                
                if habit.icon.hasPrefix("Icon-") {
                    Image(habit.icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.primary)
                } else if habit.icon == "None" {
                    // No icon selected - show colored rounded rectangle
                    RoundedRectangle(cornerRadius: 8)
                        .fill(habit.color)
                        .frame(width: 24, height: 24)
                } else {
                    Text(habit.icon)
                        .font(.system(size: 24))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.primary)
                
                Text(habit.description.isEmpty ? "Description" : habit.description)
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
            }
            
            Spacer()
            
            // Active status tag
            Text("Active")
                .font(.appLabelSmall)
                .foregroundColor(.onPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Habit Details Section
    private var habitDetailsSection: some View {
        VStack(spacing: 16) {
            // Goal
            HStack {
                Image(systemName: "flag")
                    .font(.system(size: 16))
                    .foregroundColor(.text05)
                
                Text("Goal")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                
                Spacer()
                
                Text(sortGoalChronologically(habit.goal))
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.primary)
                    .onAppear {
                        print("🔍 HABIT DETAIL - Raw goal: '\(habit.goal)'")
                        print("🔍 HABIT DETAIL - Sorted goal: '\(sortGoalChronologically(habit.goal))'")
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Reminders Section
    private var remindersSection: some View {
        VStack(spacing: 16) {
            // Reminders header
            HStack {
                Text("Reminders")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                
                Spacer()
                
                Button(action: {
                    showingReminderSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            
            // Reminders list
            if !habit.reminders.isEmpty {
                VStack(spacing: 12) {
                    ForEach(habit.reminders, id: \.id) { reminder in
                        reminderRow(for: reminder)
                    }
                }
            } else {
                // Empty state
                HStack {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 16))
                        .foregroundColor(.text04)
                    
                    Text("No reminders set")
                        .font(.appBodySmall)
                        .foregroundColor(.text04)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private func reminderRow(for reminder: ReminderItem) -> some View {
        HStack(spacing: 12) {
            // Time icon
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(width: 20)
            
            // Time text
            Text(formatReminderTime(reminder.time))
                .font(.appBodyMedium)
                .foregroundColor(.text01)
            
            Spacer()
            
            // Edit button
            Button(action: {
                selectedReminder = reminder
                showingReminderSheet = true
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.text03)
            }
            
            // Delete button
            Button(action: {
                deleteReminder(reminder)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.surfaceContainer.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatReminderTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    private func deleteReminder(_ reminder: ReminderItem) {
        print("🗑️ HabitDetailView: Deleting reminder with ID: \(reminder.id)")
        print("🗑️ HabitDetailView: Current reminders count: \(habit.reminders.count)")
        
        let updatedReminders = habit.reminders.filter { $0.id != reminder.id }
        print("🗑️ HabitDetailView: Updated reminders count: \(updatedReminders.count)")
        
        let updatedHabit = Habit(
            id: habit.id,
            name: habit.name,
            description: habit.description,
            icon: habit.icon,
            color: habit.color,
            habitType: habit.habitType,
            schedule: habit.schedule,
            goal: habit.goal,
            reminder: habit.reminder,
            startDate: habit.startDate,
            endDate: habit.endDate,
            isCompleted: habit.isCompleted,
            streak: habit.streak,
            createdAt: habit.createdAt,
            reminders: updatedReminders,
            baseline: habit.baseline,
            target: habit.target,
            completionHistory: habit.completionHistory,
            actualUsage: habit.actualUsage
        )
        
        // Update the local state first
        habit = updatedHabit
        
        // Update notifications for the habit
        print("🔄 HabitDetailView: Updating notifications for habit '\(updatedHabit.name)' with \(updatedReminders.count) reminders")
        NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: updatedReminders)
        
        print("🗑️ HabitDetailView: Calling onUpdateHabit callback")
        onUpdateHabit?(updatedHabit)
        print("🗑️ HabitDetailView: Delete reminder completed")
    }
    
    // MARK: - Today's Progress Section
    private var todayProgressSection: some View {
        VStack(spacing: 16) {
            // Progress header
            HStack {
                Text("Progress for \(formattedSelectedDate)")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                
                Spacer()
                
//                Text("\(todayProgress)/\(extractGoalAmount(from: habit.goal))")
//                    .font(.appTitleSmallEmphasised)
//                    .foregroundColor(.primary)
            }
            
            // Progress bar
            progressBar
            
            // Increment/Decrement controls
            HStack(spacing: 16) {
                Spacer()
                
                // Decrement button
                Button(action: {
                    if todayProgress > 0 {
                        todayProgress -= 1
                        updateHabitProgress(todayProgress)
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.onPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary)
                        .clipShape(Circle())
                }
                
                // Current count
                Text("\(todayProgress)")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.primary)
                    .frame(width: 40)
                
                // Increment button
                Button(action: {
                    todayProgress += 1
                    updateHabitProgress(todayProgress)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.onPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.surfaceContainer)
                        .frame(height: 4)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary)
                        .frame(width: geometry.size.width * min(CGFloat(todayProgress) / CGFloat(extractGoalNumber(from: habit.goal)), 1.0), height: 4)
                        .opacity(VacationManager.shared.isVacationDay(Date()) ? 0.6 : 1.0)
                }
            }
            .frame(height: 4)
            
            // Progress numbers
            HStack {
                Text("0")
                    .font(.appLabelSmall)
                    .foregroundColor(.text05)
                
                Spacer()
                
                Text("\(extractGoalNumber(from: habit.goal))")
                    .font(.appLabelSmall)
                    .foregroundColor(.text05)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var formattedDate: String {
        return AppDateFormatter.shared.formatDisplayDate(Date())
    }
    
    private var formattedSelectedDate: String {
        return AppDateFormatter.shared.formatDisplayDate(selectedDate)
    }
    
    // MARK: - Helper Functions
    private func extractGoalNumber(from goalString: String) -> Int {
        // Extract the number from goal strings like "5 times on 1 times a week", "20 pages on everyday", etc.
        // For legacy habits, it might still be "per"
        // First, extract the goal amount part (before "on" or "per")
        var components = goalString.components(separatedBy: " on ")
        if components.count < 2 {
            // Try with " per " for legacy habits
            components = goalString.components(separatedBy: " per ")
        }
        let goalAmount = components.first ?? goalString
        
        // Then extract the number from the goal amount
        let amountComponents = goalAmount.components(separatedBy: " ")
        if let firstComponent = amountComponents.first, let number = Int(firstComponent) {
            return number
        }
        return 1 // Default to 1 if parsing fails
    }
    
    private func updateHabitProgress(_ progress: Int) {
        // Update the habit's progress for the selected date
        var updatedHabit = habit
        let dateKey = Habit.dateKey(for: selectedDate)
        updatedHabit.completionHistory[dateKey] = progress
        
        // Update the local habit state
        habit = updatedHabit
        
        // Notify parent view of the change
        onUpdateHabit?(updatedHabit)
    }
    
    // Helper function to sort goal text chronologically 
    private func sortGoalChronologically(_ goal: String) -> String {
        // Goal strings are like "1 time on every friday, every monday" (both habit types now use "on")
        // Legacy: "1 time per every friday, every monday" (old habit breaking format)
        // We need to extract and sort the frequency part
        
        print("🔍 HABIT DETAIL GOAL SORT - Input: '\(goal)'")
        
        if goal.contains(" on ") {
            // Both habit building and new habit breaking format: "1 time on every friday, every monday"  
            let parts = goal.components(separatedBy: " on ")
            if parts.count >= 2 {
                let beforeOn = parts[0] // "1 time"
                let frequency = parts[1] // "every friday, every monday"
                
                let sortedFrequency = sortScheduleChronologically(frequency)
                let result = "\(beforeOn) on \(sortedFrequency)"
                print("🔍 HABIT DETAIL GOAL SORT - Result: '\(result)'")
                return result
            }
        } else if goal.contains(" per ") {
            // Legacy habit breaking format: "1 time per every friday, every monday"
            // Convert to "on" format for consistent display
            let parts = goal.components(separatedBy: " per ")
            if parts.count >= 2 {
                let beforePer = parts[0] // "1 time"
                let frequency = parts[1] // "every friday, every monday"
                
                let sortedFrequency = sortScheduleChronologically(frequency)
                let result = "\(beforePer) on \(sortedFrequency)" // Changed "per" to "on"
                print("🔍 HABIT DETAIL GOAL SORT - Converted legacy 'per' to 'on': '\(result)'")
                return result
            }
        }
        
        print("🔍 HABIT DETAIL GOAL SORT - No sorting needed, returning as-is")
        return goal
    }
    
    // Helper function to sort schedule text chronologically 
    private func sortScheduleChronologically(_ schedule: String) -> String {
        // Sort weekdays in chronological order for display
        // e.g., "every friday, every monday" → "every monday, every friday"
        
        print("🔍 HABIT DETAIL SORT - Input: '\(schedule)'")
        let lowercasedSchedule = schedule.lowercased()
        
        // Check if it contains multiple weekdays (be flexible with separators)
        if (lowercasedSchedule.contains("every") || lowercasedSchedule.contains("monday") || 
            lowercasedSchedule.contains("tuesday") || lowercasedSchedule.contains("wednesday") || 
            lowercasedSchedule.contains("thursday") || lowercasedSchedule.contains("friday") || 
            lowercasedSchedule.contains("saturday") || lowercasedSchedule.contains("sunday")) && 
           (lowercasedSchedule.contains(",") || lowercasedSchedule.contains(" and ")) {
            
            print("🔍 HABIT DETAIL SORT - Detected multi-day schedule")
            
            // Handle different separators: ", " or " and " or ", and"
            let dayPhrases: [String]
            if schedule.contains(", and ") {
                dayPhrases = schedule.components(separatedBy: ", and ")
            } else if schedule.contains(" and ") {
                dayPhrases = schedule.components(separatedBy: " and ")
            } else {
                dayPhrases = schedule.components(separatedBy: ", ")
            }
            
            print("🔍 HABIT DETAIL SORT - Day phrases: \(dayPhrases)")
            
            // Sort by weekday order
            let weekdayOrder = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            
            let sortedPhrases = dayPhrases.sorted { phrase1, phrase2 in
                let lowercased1 = phrase1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercased2 = phrase2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Find which weekday each phrase contains
                let day1Index = weekdayOrder.firstIndex { lowercased1.contains($0) } ?? 99
                let day2Index = weekdayOrder.firstIndex { lowercased2.contains($0) } ?? 99
                
                print("🔍 HABIT DETAIL SORT - '\(phrase1.trimmingCharacters(in: .whitespacesAndNewlines))' (index \(day1Index)) vs '\(phrase2.trimmingCharacters(in: .whitespacesAndNewlines))' (index \(day2Index))")
                return day1Index < day2Index
            }
            
            // Clean up whitespace and rejoin
            let cleanedPhrases = sortedPhrases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let result = cleanedPhrases.joined(separator: ", ")
            print("🔍 HABIT DETAIL SORT - Sorted result: '\(result)'")
            return result
        }
        
        print("🔍 HABIT DETAIL SORT - Not a multi-day schedule, returning as-is")
        // Return as-is if it's not a multi-day weekday schedule
        return schedule
    }
    
    // Helper function to extract goal amount without schedule
    private func extractGoalAmount(from goal: String) -> String {
        // Goal format is typically "X unit on frequency" (e.g., "1 time on 1 times a week")
        // For legacy habits, it might still be "X unit per frequency"
        // We want to extract just "X unit" part
        
        // Try splitting by " on " first (current format)
        var components = goal.components(separatedBy: " on ")
        if components.count >= 2 {
            return components[0] // Return "X unit" part
        }
        
        // Try splitting by " per " for legacy habits
        components = goal.components(separatedBy: " per ")
        if components.count >= 2 {
            return components[0] // Return "X unit" part
        }
        
        return goal // Fallback to original goal if format is unexpected
    }
}

// MARK: - Reminder Edit Sheet
struct ReminderEditSheet: View {
    let habit: Habit
    let reminder: ReminderItem?
    let onSave: (Habit) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime = Date()
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Time picker
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reminder Time")
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.text01)
                    
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle(reminder == nil ? "Add Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(.text03)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReminder()
                    }
                    .font(.appBodyMediumEmphasised)
                    .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            if let reminder = reminder {
                selectedTime = reminder.time
                isEditing = true
            }
        }
    }
    
    private func saveReminder() {
        if isEditing, let reminder = reminder {
            // Update existing reminder - preserve the original ID
            let updatedReminders = habit.reminders.map { existingReminder in
                if existingReminder.id == reminder.id {
                    var updatedReminder = existingReminder
                    updatedReminder.time = selectedTime
                    return updatedReminder
                }
                return existingReminder
            }
            
            let updatedHabit = Habit(
                id: habit.id,
                name: habit.name,
                description: habit.description,
                icon: habit.icon,
                color: habit.color,
                habitType: habit.habitType,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: habit.isCompleted,
                streak: habit.streak,
                createdAt: habit.createdAt,
                reminders: updatedReminders,
                baseline: habit.baseline,
                target: habit.target,
                completionHistory: habit.completionHistory,
                actualUsage: habit.actualUsage
            )
            
            // Update notifications for the habit
            print("🔄 HabitDetailView: Updating notifications for habit '\(updatedHabit.name)' with \(updatedReminders.count) reminders (editing)")
            NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: updatedReminders)
            
            onSave(updatedHabit)
        } else {
            // Create new reminder
            let newReminder = ReminderItem(time: selectedTime, isActive: true)
            let updatedReminders = habit.reminders + [newReminder]
            
            let updatedHabit = Habit(
                id: habit.id,
                name: habit.name,
                description: habit.description,
                icon: habit.icon,
                color: habit.color,
                habitType: habit.habitType,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: habit.isCompleted,
                streak: habit.streak,
                createdAt: habit.createdAt,
                reminders: updatedReminders,
                baseline: habit.baseline,
                target: habit.target,
                completionHistory: habit.completionHistory,
                actualUsage: habit.actualUsage
            )
            
            // Update notifications for the habit
            print("🔄 HabitDetailView: Updating notifications for habit '\(updatedHabit.name)' with \(updatedReminders.count) reminders (creating new)")
            NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: updatedReminders)
            
            onSave(updatedHabit)
        }
        
        dismiss()
    }
}

#Preview {
    HabitDetailView(habit: Habit(
        name: "Read a book",
        description: "Read for 30 minutes",
        icon: "📚",
        color: .blue,
        habitType: .formation,
        schedule: "Every 2 days",
        goal: "1 time a day",
        reminder: "9:00 AM",
        startDate: Date(),
        endDate: nil,
        isCompleted: false,
        streak: 5
    ), onUpdateHabit: nil, selectedDate: Date(), onDeleteHabit: nil)
} 
