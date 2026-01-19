import SwiftUI

// MARK: - DetailTab

enum DetailTab {
  case details
  case progress
}

// MARK: - HabitDetailView

struct HabitDetailView: View {
  // MARK: Internal

  @State var habit: Habit

  let onUpdateHabit: ((Habit) -> Void)?
  let selectedDate: Date
  let onDeleteHabit: ((Habit) -> Void)?

  var body: some View {
    NavigationView {
      ScrollViewReader { _ in
        ScrollView {
          contentView
        }
        .background(.appSurface01Variant02)
      }
      .onAppear {
        // ✅ FIX: Reload habit from repository to ensure we have the latest version
        // This fixes the issue where edited habit changes don't show when reopening the detail view
        Task {
          // Try to find the latest version from HabitRepository
          if let latestHabit = HabitRepository.shared.habits.first(where: { $0.id == habit.id }) {
            await MainActor.run {
              // Only update if the habit actually changed to avoid unnecessary re-renders
              if latestHabit.name != habit.name || 
                 latestHabit.icon != habit.icon ||
                 latestHabit.description != habit.description ||
                 latestHabit.reminder != habit.reminder ||
                 latestHabit.reminders != habit.reminders {
                habit = latestHabit
              }
            }
          }
        }
        
        todayProgress = habit.getProgress(for: selectedDate)
        isHabitSkipped = habit.isSkipped(for: selectedDate)
        
        // Always recalculate active state based on current habit's dates
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.startOfDay(for: habit.startDate)
        let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
        let calculatedActiveState = today >= startDate && today <= endDate

        // Only update if we haven't initialized yet, or if it's different from current state
        // This prevents unnecessary onChange triggers
        if !hasInitializedActiveState || isActive != calculatedActiveState {
          // Guard against triggering onChange during initialization
          isProcessingToggle = true
          isActive = calculatedActiveState
          isProcessingToggle = false
          hasInitializedActiveState = true
        }
      }
      .navigationTitle(habit.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button(action: {
              showingEditView = true
            }) {
              Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive, action: {
              print("🗑️ DELETE_FLOW: HabitDetailView - Delete button tapped for habit: \(habit.name) (ID: \(habit.id))")
              showingDeleteConfirmation = true
            }) {
              Label("Delete", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
      .toolbarBackground(.hidden, for: .navigationBar)
      .navigationViewStyle(.stack)
    }
    .onChange(of: habit.id) { _, _ in
      // Reset initialization flag when habit changes
      hasInitializedActiveState = false
    }
    .onChange(of: habit.endDate) { _, newEndDate in
      // Recalculate active state when endDate changes
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: Date())
      let startDate = calendar.startOfDay(for: habit.startDate)
      let endDate = newEndDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
      let calculatedActiveState = today >= startDate && today <= endDate

      // Only update if different to avoid unnecessary triggers
      if isActive != calculatedActiveState {
        isProcessingToggle = true
        isActive = calculatedActiveState
        isProcessingToggle = false
      }
    }
    .onChange(of: selectedDate) { oldDate, newDate in
      // Only update progress if the date actually changed
      let calendar = Calendar.current
      let oldDay = calendar.startOfDay(for: oldDate)
      let newDay = calendar.startOfDay(for: newDate)

      if oldDay != newDay {
        todayProgress = habit.getProgress(for: selectedDate)
        isHabitSkipped = habit.isSkipped(for: selectedDate)
      }
    }
    .sheet(isPresented: $showingEditView) {
      HabitEditView(habit: habit, onSave: { updatedHabit in
        habit = updatedHabit
        onUpdateHabit?(updatedHabit)
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
        })
    }
    .sheet(isPresented: $showingSkipSheet) {
      SkipHabitSheet(
        habitName: habit.name,
        habitColor: habit.color.color,
        onSkip: { reason in
          skipHabit(reason: reason)
        }
      )
      .presentationDetents([.height(340)])
      .presentationDragIndicator(.hidden)
    }
    .alert("Delete Habit", isPresented: $showingDeleteConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        print("🗑️ DELETE_FLOW: HabitDetailView - Delete confirmed, calling onDeleteHabit callback for habit: \(habit.name) (ID: \(habit.id))")
        onDeleteHabit?(habit)
        print("🗑️ DELETE_FLOW: HabitDetailView - onDeleteHabit callback completed, dismissing view")
        dismiss()
      }
    } message: {
      Text("Are you sure you want to delete this habit? This action cannot be undone.")
    }
    .alert("Make Habit Inactive", isPresented: $showingInactiveConfirmation) {
      Button("Cancel", role: .cancel) {
        // No action needed - toggle already reverted
      }
      Button("Make Inactive", role: .destructive) {
        // Prevent onChange from triggering during the entire process
        isProcessingToggle = true

        // Create updated habit with endDate set to yesterday (end of yesterday)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

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
          endDate: yesterday,
          createdAt: habit.createdAt,
          reminders: habit.reminders,
          baseline: habit.baseline,
          target: habit.target,
          completionHistory: habit.completionHistory,
          completionTimestamps: habit.completionTimestamps,
          difficultyHistory: habit.difficultyHistory,
          actualUsage: habit.actualUsage)

        // Update habit and notify parent
        habit = updatedHabit
        onUpdateHabit?(updatedHabit)

        // Dismiss immediately - don't try to update toggle state
        // The view will be gone, so no need to manage state
        dismiss()
      }
    } message: {
      Text(
        "This habit will be inactive and doesn't appear in the home screen from today.")
    }
    .alert("Delete Reminder", isPresented: $showingReminderDeleteConfirmation) {
      Button("Cancel", role: .cancel) {
        reminderToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let reminder = reminderToDelete {
          deleteReminder(reminder)
          reminderToDelete = nil
        }
      }
    } message: {
      Text("Are you sure you want to delete this reminder?")
    }
    .sheet(isPresented: $showingCompletionSheet) {
      HabitCompletionBottomSheet(
        isPresented: $showingCompletionSheet,
        habit: habit,
        completionDate: selectedDate,
        onDismiss: {
          print(
            "🎯 COMPLETION_FLOW: Detail sheet dismissed - habitId=\(habit.id), dateKey=\(Habit.dateKey(for: selectedDate)), sheetAction=close, reorderTriggered=true")

          // Reset flags
          isCompletingHabit = false
        })
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(40)
    }
    .sheet(isPresented: $showingCompletionInputSheet) {
      CompletionInputSheet(
        isPresented: $showingCompletionInputSheet,
        habit: habit,
        date: selectedDate,
        onSave: { newCount in
          todayProgress = newCount
          updateHabitProgress(newCount)
          
          // Check if habit is completed and show completion sheet
          let goalAmount = extractGoalNumber(from: habit.goal)
          if newCount >= goalAmount {
            isCompletingHabit = true
            showingCompletionSheet = true
          }
        }
      )
    }
    .fullScreenCover(isPresented: $showingNotificationsSettings) {
      NotificationsView()
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var selectedTab: DetailTab = .details
  @State private var todayProgress = 0
  @State private var showingEditView = false
  @State private var showingDeleteConfirmation = false
  @State private var showingReminderSheet = false
  @State private var selectedReminder: ReminderItem?
  @State private var showingReminderDeleteConfirmation = false
  @State private var reminderToDelete: ReminderItem?
  @State private var isActive = true
  @State private var showingInactiveConfirmation = false
  @State private var isProcessingToggle = false
  @State private var hasInitializedActiveState = false
  @State private var showingCompletionSheet = false
  @State private var showingCompletionInputSheet = false
  @State private var isCompletingHabit = false
  @State private var showingNotificationsSettings = false
  @State private var showingSkipSheet = false
  @State private var isHabitSkipped = false

  /// Check if habit reminders are globally enabled - using @AppStorage for automatic updates
  @AppStorage("habitReminderEnabled") private var habitRemindersEnabled = true

  private var formattedDate: String {
    AppDateFormatter.shared.formatDisplayDate(Date())
  }

  private var formattedSelectedDate: String {
    AppDateFormatter.shared.formatDisplayDate(selectedDate)
  }

  // MARK: - Content View (shared between scrollable and static)

  private var contentView: some View {
    VStack(spacing: 0) {
      // Segmented control
      tabSegmentedControl
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
      
      // Tab content
      if selectedTab == .details {
        detailsTabContent
      } else {
        progressTabContent
      }
    }
  }
  
  // MARK: - Tab Segmented Control
  
  private var tabSegmentedControl: some View {
    HStack(spacing: 8) {
      tabButton(title: "Details", tab: .details)
      tabButton(title: "Progress", tab: .progress)
      Spacer()
    }
  }
  
  private func tabButton(title: String, tab: DetailTab) -> some View {
    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedTab = tab
      }
    }) {
      HStack(spacing: 4) {
        if selectedTab == tab {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.appOnPrimaryContainer)
        }
        Text(title)
          .font(selectedTab == tab ? .appLabelMediumEmphasised : .appLabelMedium)
          .foregroundColor(selectedTab == tab ? .appOnPrimaryContainer : .appText03)
      }
      .padding(.leading, selectedTab == tab ? 16 : 12)
      .padding(.trailing, 12)
      .frame(height: 32)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(selectedTab == tab ? Color.appPrimaryContainer : Color.clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(selectedTab == tab ? Color.clear : Color.appOutline02, lineWidth: 1)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  // MARK: - Details Tab Content
  
  private var detailsTabContent: some View {
    VStack(spacing: 0) {
      // Main content card
      mainContentCard
        .padding(.top, 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)

      // Active/Inactive toggle section
      activeInactiveToggleSection
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
  }
  
  // MARK: - Progress Tab Content
  
  private var progressTabContent: some View {
    VStack(spacing: 16) {
      // Week Calendar Strip
      weekCalendarStrip
        .padding(.horizontal, 16)
        .padding(.top, 4)
      
      // Streak Stats Card
      streakStatsCard
        .padding(.horizontal, 16)
      
      // This Month Summary
      thisMonthSummary
        .padding(.horizontal, 16)
      
      // Monthly History
      monthlyHistory
        .padding(.horizontal, 16)
      
      // See More Progress Button
      seeMoreProgressButton
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
  }
  
  // MARK: - See More Progress Button
  
  private var seeMoreProgressButton: some View {
    Button(action: {
      // Navigate to Progress tab with this habit selected
      navigateToProgressTab()
    }) {
      HStack {
        // Left: "See More Progress" label
        Text("See More Progress")
          .font(.appLabelLargeEmphasised)
          .foregroundColor(Color("grey700"))
        
        Spacer()
        
        // Right: Arrow icon
        Image(systemName: "chevron.right")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(Color("navy500"))
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color("appSecondaryContainerFixed02"))
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func navigateToProgressTab() {
    // Dismiss the current sheet
    dismiss()
    
    // Post notification to switch to Progress tab and select this habit
    NotificationCenter.default.post(
      name: NSNotification.Name("SwitchToProgressTabWithHabit"),
      object: nil,
      userInfo: ["habitId": habit.id]
    )
  }
  
  // MARK: - Week Calendar Strip
  
  private var weekCalendarStrip: some View {
    let calendar = Calendar.current
    let today = Date()
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    
    return VStack(alignment: .leading, spacing: 12) {
      Text("This Week")
        .font(.appBodyMediumEmphasised)
        .foregroundColor(.text01)
      
      HStack(spacing: 8) {
        ForEach(0..<7) { dayOffset in
          if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
            weekDayItem(for: date)
          }
        }
      }
    }
    .padding(16)
    .background(Color.appSurface01Variant)
    .cornerRadius(16)
  }
  
  private func weekDayItem(for date: Date) -> some View {
    let calendar = Calendar.current
    let weekdaySymbol = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
    let dayNumber = calendar.component(.day, from: date)
    let isScheduled = StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
    let progress = habit.getProgress(for: date)
    let goalAmount = extractGoalNumber(from: habit.goal)
    
    return VStack(spacing: 6) {
      Text(String(weekdaySymbol.prefix(1)))
        .font(.appLabelSmall)
        .foregroundColor(.text05)
      
      ZStack {
        Circle()
          .stroke(completionStatus(progress: progress, goal: goalAmount, isScheduled: isScheduled).color.opacity(0.3), lineWidth: 2)
          .frame(width: 32, height: 32)
        
        if isScheduled {
          Circle()
            .fill(completionStatus(progress: progress, goal: goalAmount, isScheduled: isScheduled).color)
            .frame(width: completionStatus(progress: progress, goal: goalAmount, isScheduled: isScheduled).size, height: completionStatus(progress: progress, goal: goalAmount, isScheduled: isScheduled).size)
        } else {
          Text("─")
            .font(.appLabelSmall)
            .foregroundColor(.text07)
        }
      }
      
      Text("\(dayNumber)")
        .font(.appLabelSmall)
        .foregroundColor(.text04)
    }
    .frame(maxWidth: .infinity)
  }
  
  private func completionStatus(progress: Int, goal: Int, isScheduled: Bool) -> (color: Color, size: CGFloat) {
    if !isScheduled {
      return (.text07, 0)
    }
    
    if progress >= goal {
      // Completed: filled circle
      return (habit.color.color, 28)
    } else if progress > 0 {
      // Partially completed: half circle
      return (habit.color.color, 14)
    } else {
      // Missed/incomplete: empty circle
      return (.text05, 0)
    }
  }
  
  // MARK: - Streak Stats Card
  
  private var streakStatsCard: some View {
    HStack(spacing: 16) {
      // Current Streak
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Text("🔥")
            .font(.system(size: 20))
          Text("Current")
            .font(.appBodySmall)
            .foregroundColor(.text05)
        }
        
        Text("\(habit.computedStreak())")
          .font(.appTitleLargeEmphasised)
          .foregroundColor(.text01)
        
        Text(habit.computedStreak() == 1 ? "day" : "days")
          .font(.appBodySmall)
          .foregroundColor(.text05)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      
      Divider()
        .frame(height: 60)
      
      // Longest Streak
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Text("🏆")
            .font(.system(size: 20))
          Text("Longest")
            .font(.appBodySmall)
            .foregroundColor(.text05)
        }
        
        Text("\(StreakDataCalculator.calculateBestStreakFromHistory(for: habit))")
          .font(.appTitleLargeEmphasised)
          .foregroundColor(.text01)
        
        Text(StreakDataCalculator.calculateBestStreakFromHistory(for: habit) == 1 ? "day" : "days")
          .font(.appBodySmall)
          .foregroundColor(.text05)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(Color.appSurface01Variant)
    .cornerRadius(16)
  }
  
  // MARK: - This Month Summary
  
  private var thisMonthSummary: some View {
    let calendar = Calendar.current
    let today = Date()
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
    let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? today
    
    let (completed, total) = calculateMonthStats(start: monthStart, end: min(monthEnd, today))
    let percentage = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
    
    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("This Month")
          .font(.appTitleSmallEmphasised)
          .foregroundColor(.text01)
        
        Spacer()
        
        Text("\(percentage)%")
          .font(.appBodyMediumEmphasised)
          .foregroundColor(.text03)
      }
      
      Text("\(completed) of \(total) days completed")
        .font(.appBodySmall)
        .foregroundColor(.text05)
      
      // Progress bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.surfaceContainer)
            .frame(height: 8)
          
          RoundedRectangle(cornerRadius: 4)
            .fill(habit.color.color)
            .frame(width: geometry.size.width * CGFloat(completed) / CGFloat(max(total, 1)), height: 8)
        }
      }
      .frame(height: 8)
    }
    .padding(16)
    .background(Color.appSurface01Variant)
    .cornerRadius(16)
  }
  
  // MARK: - Monthly History
  
  private var monthlyHistory: some View {
    let months = last3Months()
    
    return VStack(alignment: .leading, spacing: 12) {
      Text("Monthly History")
        .font(.appTitleSmallEmphasised)
        .foregroundColor(.text01)
      
      VStack(spacing: 12) {
        ForEach(months, id: \.monthStart) { monthData in
          monthHistoryRow(monthData: monthData)
        }
      }
    }
    .padding(16)
    .background(Color.appSurface01Variant)
    .cornerRadius(16)
  }
  
  private func monthHistoryRow(monthData: (monthStart: Date, monthName: String)) -> some View {
    let calendar = Calendar.current
    let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthData.monthStart) ?? monthData.monthStart
    let (completed, total) = calculateMonthStats(start: monthData.monthStart, end: min(monthEnd, Date()))
    let percentage = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
    
    return HStack(spacing: 12) {
      Text(monthData.monthName)
        .font(.appBodyMedium)
        .foregroundColor(.text03)
        .frame(width: 80, alignment: .leading)
      
      // Progress bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.surfaceContainer)
            .frame(height: 8)
          
          RoundedRectangle(cornerRadius: 4)
            .fill(habit.color.color)
            .frame(width: geometry.size.width * CGFloat(completed) / CGFloat(max(total, 1)), height: 8)
        }
      }
      .frame(height: 8)
      
      Text("\(percentage)%")
        .font(.appBodySmall)
        .foregroundColor(.text05)
        .frame(width: 40, alignment: .trailing)
    }
  }
  
  private func calculateMonthStats(start: Date, end: Date) -> (completed: Int, total: Int) {
    let calendar = Calendar.current
    var currentDate = start
    var completed = 0
    var total = 0
    
    while currentDate <= end {
      if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
        total += 1
        let progress = habit.getProgress(for: currentDate)
        let goalAmount = extractGoalNumber(from: habit.goal)
        if progress >= goalAmount {
          completed += 1
        }
      }
      
      guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
      currentDate = nextDate
    }
    
    return (completed, total)
  }
  
  private func last3Months() -> [(monthStart: Date, monthName: String)] {
    let calendar = Calendar.current
    let today = Date()
    var months: [(Date, String)] = []
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM yyyy"
    
    for monthOffset in 1...3 {
      if let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: today),
         let monthStartDay = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)) {
        let monthName = dateFormatter.string(from: monthStartDay)
        months.append((monthStartDay, monthName))
      }
    }
    
    return months
  }

  // MARK: - Main Content Card

  private var mainContentCard: some View {
    VStack(spacing: 0) {
      // Habit Summary Section
      habitSummarySection

      Divider()
        .padding(.horizontal, 16)

      // Completion Ring Section
      completionRingSection

      Divider()
        .padding(.horizontal, 16)

      // Quick Stats Section
      quickStatsSection

      Divider()
        .padding(.horizontal, 16)

      // Habit Details Section (Goal)
      habitDetailsSection

      Divider()
        .padding(.horizontal, 16)

      // Reminders Section
      remindersSection
    }
    .background(.appSurface01Variant)
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
            .fill(habit.color.color)
            .frame(width: 24, height: 24)
        } else {
          Text(habit.icon)
            .font(.system(size: 24))
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(habit.name)
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.appText01)

        if !habit.description.isEmpty {
          Text(habit.description)
            .font(.appBodyMedium)
            .foregroundColor(.text05)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
  }

  // MARK: - Completion Ring Section
  
  private var completionRingSection: some View {
    VStack(spacing: 0) {
      CompletionRingView(
        progress: Double(todayProgress) / Double(max(extractGoalNumber(from: habit.goal), 1)),
        currentValue: todayProgress,
        goalValue: extractGoalNumber(from: habit.goal),
        unit: extractUnitFromGoal(habit.goal),
        habitColor: habit.color.color,
        onTap: {
          showingCompletionInputSheet = true
        },
        isSkipped: isHabitSkipped,
        onSkip: {
          if isHabitSkipped {
            unskipHabit()
          } else {
            showingSkipSheet = true
          }
        }
      )
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, 24)
  }
  
  // MARK: - Quick Stats Section
  
  private var quickStatsSection: some View {
    VStack(spacing: 0) {
      QuickStatsRow(
        currentStreak: habit.computedStreak(),
        isScheduledToday: StreakDataCalculator.shouldShowHabitOnDate(habit, date: Date()),
        isCompletedToday: habit.getProgress(for: Date()) >= extractGoalNumber(from: habit.goal),
        nextScheduledDate: calculateNextScheduledDate(for: habit)
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
  }

  // MARK: - Habit Details Section

  private var habitDetailsSection: some View {
    VStack(spacing: 16) {
      // Goal
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: "flag")
            .font(.system(size: 16))
            .foregroundColor(.text05)

          Text("Goal")
            .font(.appBodyMedium)
            .foregroundColor(.text05)
        }

        Text(sortGoalChronologically(habit.goal))
          .font(.appTitleSmallEmphasised)
          .foregroundColor(.primary)
          .fixedSize(horizontal: false, vertical: true)
          .onAppear { }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
  }

  // MARK: - Reminders Section

  private var remindersSection: some View {
    VStack(spacing: 16) {
      // Reminders header
      HStack {
        Image("Icon-Bell_Outlined")
          .resizable()
          .renderingMode(.template)
          .frame(width: 16, height: 16)
          .foregroundColor(.text05)

        Text("Reminders")
          .font(.appBodyMedium)
          .foregroundColor(.text05)

        Spacer()

        Button(action: {
          showingReminderSheet = true
        }) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 20))
            .foregroundColor(habitRemindersEnabled ? .primary : .text04)
        }
        .disabled(!habitRemindersEnabled)
      }

      // Compact warning when habit reminders are disabled
      if !habitRemindersEnabled {
        Button(action: {
          showingNotificationsSettings = true
        }) {
          HStack(spacing: 8) {
            Text("⚠️")
              .font(.system(size: 14))
            
            Text("Reminders off")
              .font(.appBodySmall)
              .foregroundColor(.text01)
            
            Text("·")
              .font(.appBodySmall)
              .foregroundColor(.text04)
            
            Text("Enable")
              .font(.appBodySmall)
              .foregroundColor(.primary)
            
            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color.orange.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
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
        Text("No reminders set")
          .font(.appBodySmall)
          .foregroundColor(.text04)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .padding(.horizontal, 16)
          .background(Color.surfaceContainer.opacity(0.5))
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
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
            let newProgress = max(0, todayProgress - 1)

            print(
              "🎯 COMPLETION_FLOW: Detail - button - habitId=\(habit.id), dateKey=\(Habit.dateKey(for: selectedDate)), source=detail, oldCount=\(todayProgress), newCount=\(newProgress), goal=\(extractGoalNumber(from: habit.goal)), reachedGoal=false")

            todayProgress = newProgress
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
          let goalAmount = extractGoalNumber(from: habit.goal)
          let newProgress = min(todayProgress + 1, goalAmount)

          print(
            "🎯 COMPLETION_FLOW: Detail + button - habitId=\(habit.id), dateKey=\(Habit.dateKey(for: selectedDate)), source=detail, oldCount=\(todayProgress), newCount=\(newProgress), goal=\(goalAmount), reachedGoal=\(newProgress >= goalAmount)")

          todayProgress = newProgress
          updateHabitProgress(todayProgress)

          // Check if habit is completed and show completion sheet
          if newProgress >= goalAmount {
            isCompletingHabit = true
            print("🎯 COMPLETION_FLOW: Showing completion sheet immediately")
            showingCompletionSheet = true
          }
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
            .frame(
              width: geometry.size
                .width *
                min(CGFloat(todayProgress) / CGFloat(extractGoalNumber(from: habit.goal)), 1.0),
              height: 4)
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

  // MARK: - Active/Inactive Toggle Section

  private var activeInactiveToggleSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle(isOn: Binding(
        get: { isActive },
        set: { newValue in
          // Prevent recursive calls
          guard !isProcessingToggle else { return }

          let oldValue = isActive

          if !newValue, oldValue {
            // Attempting to make inactive - show confirmation
            showingInactiveConfirmation = true
            // Don't change isActive yet - wait for confirmation
          } else if newValue, !oldValue {
            // Making active - no confirmation needed
            isProcessingToggle = true
            isActive = true

            // Create updated habit with endDate removed
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
              endDate: nil,
              createdAt: habit.createdAt,
              reminders: habit.reminders,
              baseline: habit.baseline,
              target: habit.target,
              completionHistory: habit.completionHistory,
              difficultyHistory: habit.difficultyHistory,
              actualUsage: habit.actualUsage)
            habit = updatedHabit
            onUpdateHabit?(updatedHabit)

            isProcessingToggle = false
          }
        })) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Active")
              .font(.appBodyLarge)
              .foregroundColor(.text01)

            Text(isActive
              ? "This habit is currently active and appears in your daily list"
              : "This habit is inactive and won't appear in your daily list")
              .font(.appBodySmall)
              .foregroundColor(.text05)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .toggleStyle(SwitchToggleStyle(tint: .green))
    }
    .padding(16)
    .background(.appSurface01Variant)
    .cornerRadius(20)
  }

  private func reminderRow(for reminder: ReminderItem) -> some View {
    HStack(spacing: 16) {
      // Time text
      Text(formatReminderTime(reminder.time))
        .font(.appBodyLarge)
        .foregroundColor(habitRemindersEnabled ? .text01 : .text04)

      Spacer()

      // Edit button
      Button(action: {
        selectedReminder = reminder
        showingReminderSheet = true
      }) {
        Image("Icon-Pen_Outlined")
          .resizable()
          .frame(width: 18, height: 18)
          .foregroundColor(habitRemindersEnabled ? .text03 : .text05)
          .padding(8)
      }
      .disabled(!habitRemindersEnabled)

      // Delete button
      Button(action: {
        reminderToDelete = reminder
        showingReminderDeleteConfirmation = true
      }) {
        Image("Icon-TrashBin3_Filled")
          .resizable()
          .frame(width: 18, height: 18)
          .foregroundColor(habitRemindersEnabled ? .red : .text05)
          .padding(8)
      }
      .disabled(!habitRemindersEnabled)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color.surfaceContainer.opacity(habitRemindersEnabled ? 0.5 : 0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .opacity(habitRemindersEnabled ? 1.0 : 0.6)
  }

  private func formatReminderTime(_ time: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: time)
  }

  private func hasReminderTimePassed(_ reminderTime: Date) -> Bool {
    let calendar = Calendar.current
    let now = Date()

    // Extract hour and minute from reminder time
    let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)

    // Extract hour and minute from current time
    let nowComponents = calendar.dateComponents([.hour, .minute], from: now)

    guard let reminderHour = reminderComponents.hour,
          let reminderMinute = reminderComponents.minute,
          let nowHour = nowComponents.hour,
          let nowMinute = nowComponents.minute else
    {
      return false
    }

    // Compare hours first
    if nowHour > reminderHour {
      return true
    } else if nowHour == reminderHour {
      return nowMinute > reminderMinute
    } else {
      return false
    }
  }

  private func deleteReminder(_ reminder: ReminderItem) {
    let updatedReminders = habit.reminders.filter { $0.id != reminder.id }

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
      createdAt: habit.createdAt,
      reminders: updatedReminders,
      baseline: habit.baseline,
      target: habit.target,
      completionHistory: habit.completionHistory,
      actualUsage: habit.actualUsage)

    // Update the local state first
    habit = updatedHabit

    // Update notifications for the habit
    NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: updatedReminders)

    onUpdateHabit?(updatedHabit)
  }

  // MARK: - Helper Functions
  
  private func calculateNextScheduledDate(for habit: Habit) -> Date? {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // Check next 30 days for next scheduled date
    for dayOffset in 1...30 {
      if let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
        if StreakDataCalculator.shouldShowHabitOnDate(habit, date: futureDate) {
          return futureDate
        }
      }
    }
    return nil
  }
  
  private func extractUnitFromGoal(_ goalString: String) -> String {
    // Extract unit from goal strings like "5 times on everyday", "20 pages on daily", etc.
    let lowerGoal = goalString.lowercased()
    
    // Try to extract unit by splitting on " on " or " per "
    var unitPart = ""
    if let onRange = lowerGoal.range(of: " on ") {
      unitPart = String(lowerGoal[..<onRange.lowerBound])
    } else if let perRange = lowerGoal.range(of: " per ") {
      unitPart = String(lowerGoal[..<perRange.lowerBound])
    } else {
      unitPart = lowerGoal
    }
    
    // Extract the unit word (everything after the number)
    let components = unitPart.components(separatedBy: " ")
    if components.count >= 2 {
      // Join all words except the first (the number)
      let unit = components.dropFirst().joined(separator: " ")
      return unit
    }
    
    return "times" // Default fallback
  }

  private func extractGoalNumber(from goalString: String) -> Int {
    // Extract the number from goal strings like "5 times on 1 times a week", "20 pages on
    // everyday", etc.
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
  
  // MARK: - Skip Feature Methods
  
  private func skipHabit(reason: SkipReason) {
    habit.skip(for: selectedDate, reason: reason)
    isHabitSkipped = true
    onUpdateHabit?(habit)
    
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    
    print("⏭️ SKIP: Habit '\(habit.name)' skipped for \(Habit.dateKey(for: selectedDate)) - reason: \(reason.rawValue)")
  }
  
  private func unskipHabit() {
    habit.unskip(for: selectedDate)
    isHabitSkipped = false
    onUpdateHabit?(habit)
    
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    
    print("⏭️ UNSKIP: Habit '\(habit.name)' unskipped for \(Habit.dateKey(for: selectedDate))")
  }

  /// Helper function to sort goal text chronologically
  private func sortGoalChronologically(_ goal: String) -> String {
    // Goal strings are like "1 time on every friday, every monday" (both habit types now use "on")
    // Legacy: "1 time per every friday, every monday" (old habit breaking format)
    // We need to extract and sort the frequency part, and convert old formats to new ones

    if goal.contains(" on ") {
      // Both habit building and new habit breaking format: "1 time on every friday, every monday"
      let parts = goal.components(separatedBy: " on ")
      if parts.count >= 2 {
        let beforeOn = parts[0] // "1 time"
        let frequency = parts[1] // "every friday, every monday" or "1 day a week"

        let sortedFrequency = sortScheduleChronologically(frequency)
        let formattedFrequency = formatFrequencyText(sortedFrequency)
        
        // Check if we need "on" or not
        if needsOnPreposition(formattedFrequency) {
          return "\(beforeOn) on \(formattedFrequency)"
        } else {
          return "\(beforeOn) \(formattedFrequency)"
        }
      }
    } else if goal.contains(" per ") {
      // Legacy habit breaking format: "1 time per every friday, every monday"
      // Convert to "on" format for consistent display
      let parts = goal.components(separatedBy: " per ")
      if parts.count >= 2 {
        let beforePer = parts[0] // "1 time"
        let frequency = parts[1] // "every friday, every monday"

        let sortedFrequency = sortScheduleChronologically(frequency)
        let formattedFrequency = formatFrequencyText(sortedFrequency)
        
        // Check if we need "on" or not
        if needsOnPreposition(formattedFrequency) {
          return "\(beforePer) on \(formattedFrequency)"
        } else {
          return "\(beforePer) \(formattedFrequency)"
        }
      }
    }

    return goal
  }
  
  /// Converts old frequency formats to new standardized formats
  private func formatFrequencyText(_ frequency: String) -> String {
    let lowerFreq = frequency.lowercased()
    
    // Format multiple "every [day]" entries into "every Monday, Wednesday & Friday" format
    let formattedDays = formatMultipleDays(frequency)
    
    // Check for "X day(s) a week" patterns
    if lowerFreq.contains("day a week") || lowerFreq.contains("days a week") {
      if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*days?\s*a\s*week"#, options: .caseInsensitive),
         let match = regex.firstMatch(in: frequency, options: [], range: NSRange(location: 0, length: frequency.count)) {
        let range = match.range(at: 1)
        if let numberRange = Range(range, in: frequency),
           let number = Int(frequency[numberRange]) {
          switch number {
          case 1: return "once a week"
          case 2: return "twice a week"
          case 7: return "everyday"
          default: return "\(number) days a week"
          }
        }
      }
    }
    
    // Check for "X day(s) a month" patterns
    if lowerFreq.contains("day a month") || lowerFreq.contains("days a month") {
      if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*days?\s*a\s*month"#, options: .caseInsensitive),
         let match = regex.firstMatch(in: frequency, options: [], range: NSRange(location: 0, length: frequency.count)) {
        let range = match.range(at: 1)
        if let numberRange = Range(range, in: frequency),
           let number = Int(frequency[numberRange]) {
          switch number {
          case 1: return "once a month"
          case 2: return "twice a month"
          default: return "\(number) days a month"
          }
        }
      }
    }
    
    // Return formatted days if it was multiple days, otherwise return original
    if formattedDays != frequency.lowercased() {
      return formattedDays
    }
    
    return frequency
  }
  
  /// Formats multiple "Every [Day]" entries into "every Monday, Wednesday & Friday" format
  private func formatMultipleDays(_ frequencyText: String) -> String {
    let lowerFrequency = frequencyText.lowercased()
    
    // Check if it contains multiple "every [day]" patterns
    if lowerFrequency.contains(", ") && lowerFrequency.contains("every ") {
      // Split by comma and extract day names
      let parts = frequencyText.components(separatedBy: ", ")
      var days: [String] = []
      
      for part in parts {
        let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLower = trimmed.lowercased()
        
        // Remove "Every " or "every " prefix and get the day name
        if trimmed.hasPrefix("Every ") {
          let dayName = String(trimmed.dropFirst(6)) // Remove "Every "
          days.append(dayName)
        } else if trimmedLower.hasPrefix("every ") {
          let dayName = String(trimmed.dropFirst(6)) // Remove "every "
          // Capitalize first letter only (e.g., "monday" -> "Monday")
          days.append(dayName.prefix(1).uppercased() + dayName.dropFirst())
        } else {
          // If it doesn't match the pattern, return original (lowercased)
          return frequencyText.lowercased()
        }
      }
      
      // Format as "every Monday, Wednesday & Friday"
      if days.isEmpty {
        return frequencyText.lowercased()
      } else if days.count == 1 {
        return "every \(days[0])"
      } else if days.count == 2 {
        return "every \(days[0]) & \(days[1])"
      } else {
        // Join all but last with commas, then add " & " before last
        let allButLast = days.dropLast().joined(separator: ", ")
        let last = days.last!
        return "every \(allButLast) & \(last)"
      }
    }
    
    // Not multiple days, return as-is (lowercased)
    return frequencyText.lowercased()
  }
  
  /// Determines if a frequency text needs the "on" preposition
  private func needsOnPreposition(_ frequencyText: String) -> Bool {
    let lowerFrequency = frequencyText.lowercased()
    
    // Frequency patterns that DON'T need "on"
    let frequencyPatterns = [
      "everyday",
      "once a week",
      "twice a week",
      "once a month",
      "twice a month",
      "day a week",
      "days a week",
      "day a month",
      "days a month",
      "time per week",
      "times per week",
    ]
    
    for pattern in frequencyPatterns {
      if lowerFrequency.contains(pattern) {
        return false
      }
    }
    
    // Everything else (specific weekdays, dates, etc.) needs "on"
    return true
  }

  /// Helper function to sort schedule text chronologically
  private func sortScheduleChronologically(_ schedule: String) -> String {
    // Sort weekdays in chronological order for display
    // e.g., "every friday, every monday" → "every monday, every friday"

    let lowercasedSchedule = schedule.lowercased()

    // Check if it contains multiple weekdays (be flexible with separators)
    if lowercasedSchedule.contains("every") || lowercasedSchedule.contains("monday") ||
      lowercasedSchedule.contains("tuesday") || lowercasedSchedule.contains("wednesday") ||
      lowercasedSchedule.contains("thursday") || lowercasedSchedule.contains("friday") ||
      lowercasedSchedule.contains("saturday") || lowercasedSchedule.contains("sunday"),
      lowercasedSchedule.contains(",") || lowercasedSchedule.contains(" and ")
    {
      // Handle different separators: ", " or " and " or ", and"
      let dayPhrases: [String] = if schedule.contains(", and ") {
        schedule.components(separatedBy: ", and ")
      } else if schedule.contains(" and ") {
        schedule.components(separatedBy: " and ")
      } else {
        schedule.components(separatedBy: ", ")
      }

      // Sort by weekday order
      let weekdayOrder = [
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday"
      ]

      let sortedPhrases = dayPhrases.sorted { phrase1, phrase2 in
        let lowercased1 = phrase1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased2 = phrase2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Find which weekday each phrase contains
        let day1Index = weekdayOrder.firstIndex { lowercased1.contains($0) } ?? 99
        let day2Index = weekdayOrder.firstIndex { lowercased2.contains($0) } ?? 99

        return day1Index < day2Index
      }

      // Clean up whitespace and rejoin
      let cleanedPhrases = sortedPhrases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      let result = cleanedPhrases.joined(separator: ", ")
      return result
    }

    // Return as-is if it's not a multi-day weekday schedule
    return schedule
  }

  /// Helper function to extract goal amount without schedule
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

// MARK: - ReminderEditSheet

struct ReminderEditSheet: View {
  // MARK: Lifecycle

  init(
    habit: Habit,
    reminder: ReminderItem?,
    onSave: @escaping (Habit) -> Void,
    onCancel: @escaping () -> Void)
  {
    self.habit = habit
    self.reminder = reminder
    self.onSave = onSave
    self.onCancel = onCancel
    // Initialize selectedTime with reminder's time or current time
    _selectedTime = State(initialValue: reminder?.time ?? Date())
  }

  // MARK: Internal

  let habit: Habit
  let reminder: ReminderItem?
  let onSave: (Habit) -> Void
  let onCancel: () -> Void

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
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var selectedTime: Date

  /// Computed property to determine if we're editing
  private var isEditing: Bool {
    reminder != nil
  }

  private func saveReminder() {
    if isEditing, let reminder {
      // Update existing reminder - preserve the original ID
      print("📝 ReminderEditSheet: Updating existing reminder with ID: \(reminder.id)")
      let updatedReminders = habit.reminders.map { existingReminder in
        if existingReminder.id == reminder.id {
          var updatedReminder = existingReminder
          updatedReminder.time = selectedTime
          print("✅ ReminderEditSheet: Updated reminder time to \(selectedTime)")
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
        createdAt: habit.createdAt,
        reminders: updatedReminders,
        baseline: habit.baseline,
        target: habit.target,
        completionHistory: habit.completionHistory,
        actualUsage: habit.actualUsage)

      // Update notifications for the habit
      NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: updatedReminders)

      onSave(updatedHabit)
    } else {
      // Create new reminder
      print("➕ ReminderEditSheet: Creating new reminder at \(selectedTime)")
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
        createdAt: habit.createdAt,
        reminders: updatedReminders,
        baseline: habit.baseline,
        target: habit.target,
        completionHistory: habit.completionHistory,
        actualUsage: habit.actualUsage)

      // Update notifications for the habit
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
    endDate: nil), onUpdateHabit: nil, selectedDate: Date(), onDeleteHabit: nil)
}
