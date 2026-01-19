import SwiftUI

// MARK: - JiggleAnimationModifier

struct JiggleAnimationModifier: ViewModifier {
  let isEditMode: Bool

  func body(content: Content) -> some View {
    content
      .rotationEffect(.degrees(isEditMode ? 1 : 0)) // Subtle tilt in edit mode
      .animation(.easeOut(duration: 0.25), value: isEditMode)
  }
}

// MARK: - HabitsTabView

struct HabitsTabView: View {
  // MARK: Lifecycle

  /// Custom initializer with default value for onUpdateHabit
  init(
    state: HomeViewState,
    onDeleteHabit: @escaping (Habit) -> Void,
    onEditHabit: @escaping (Habit) -> Void,
    onCreateHabit: @escaping () -> Void,
    onUpdateHabit: ((Habit) -> Void)? = nil)
  {
    self.state = state
    self.onDeleteHabit = onDeleteHabit
    self.onEditHabit = onEditHabit
    self.onCreateHabit = onCreateHabit
    self.onUpdateHabit = onUpdateHabit
  }

  // MARK: Internal

  @ObservedObject var state: HomeViewState
  @EnvironmentObject var themeManager: ThemeManager

  let onDeleteHabit: (Habit) -> Void
  let onEditHabit: (Habit) -> Void
  let onCreateHabit: () -> Void
  let onUpdateHabit: ((Habit) -> Void)?

  var body: some View {
    WhiteSheetContainer(
      title: "Habits",
      headerContent: {
        AnyView(
          VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
              // Stats row with tabs on the left
              statsRow
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 0)
                .padding(.top, 2)
                .padding(.bottom, 0)

              // Edit button on the right
              if !filteredHabits.isEmpty {
                EditButton()
                  .font(.appButtonText2)
                  .foregroundColor(.accentColor)
                  .padding(.trailing, 20)
              }
            }
          }
          .overlay(
            // Full-width underline stroke at the bottom, spanning entire screen width
            VStack {
              Spacer()
              Rectangle()
                .fill(Color.outline2)
                .frame(height: 1)
            }
            .frame(maxWidth: .infinity)
          )
        )
      },
      headerBackground: .surface01,
      contentBackground: .surface01) {
        if habits.isEmpty {
          // No habits created in the app at all
          VStack {
            HabitEmptyStateView.noHabitsYet()
              .frame(maxWidth: .infinity, alignment: .center)
          }
          .padding(.top, 18)
        } else if filteredHabits.isEmpty {
          // No habits for the selected tab
          VStack {
            emptyStateViewForTab
              .frame(maxWidth: .infinity, alignment: .center)
          }
          .padding(.top, 18)
        } else {
          List {
            ForEach(filteredHabits) { habit in
              habitListRow(habit)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onMove(perform: moveHabit)
            .onDelete(perform: deleteHabit)
            
            // Recently Deleted section
            if recentlyDeletedCount > 0 {
              Section {
                Button(action: {
                  showingRecentlyDeleted = true
                }) {
                  HStack(spacing: 12) {
                    Image(systemName: "trash")
                      .font(.system(size: 18))
                      .foregroundColor(.secondary)
                    
                    Text("Recently Deleted")
                      .font(.appBodyLarge)
                      .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(recentlyDeletedCount)")
                      .font(.appCaptionMedium)
                      .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                      .font(.system(size: 14))
                      .foregroundColor(.secondary)
                  }
                  .padding(.vertical, 12)
                  .padding(.horizontal, 16)
                  .background(Color(.systemGray6))
                  .cornerRadius(8)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
              }
            }
            
            Spacer()
              .frame(height: 80)
              .listRowInsets(EdgeInsets())
              .listRowSeparator(.hidden)
              .listRowBackground(Color.clear)
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
          .padding(.top, 18)
          .animation(.default, value: filteredHabits.map { $0.id })
          .refreshable {
            await refreshHabits()
          }
        }
      }
      .environment(\.editMode, $editMode)
      .fullScreenCover(item: $selectedHabit) { habit in
        HabitDetailView(
          habit: habit,
          onUpdateHabit: onUpdateHabit,
          selectedDate: Date(),
          onDeleteHabit: onDeleteHabit)
          .gesture(
            DragGesture()
              .onEnded { value in
                // Swipe right to dismiss (like back button)
                if value.translation.width > 100, abs(value.translation.height) < 100 {
                  selectedHabit = nil
                }
              })
      }
      .sheet(isPresented: $showingRecentlyDeleted) {
        RecentlyDeletedView()
      }
      .onAppear {
        // Debug: Check for duplicate habits
        debugCheckForDuplicates()
        
        // Load recently deleted count
        Task {
          await updateRecentlyDeletedCount()
        }
      }
      .onChange(of: habits) { oldValue, newValue in
        // Update recently deleted count when habits change
        Task {
          await updateRecentlyDeletedCount()
        }
      }
  }

  // MARK: Private

  @State private var selectedStatsTab = 0
  @State private var selectedHabit: Habit? = nil
  @State private var editMode: EditMode = .inactive
  @State private var recentlyDeletedCount = 0
  @State private var showingRecentlyDeleted = false

  /// Computed property for habits
  private var habits: [Habit] {
    let habitsArray = state.habits
    
    return habitsArray
  }

  private var filteredHabits: [Habit] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // First, deduplicate habits by ID to prevent UI duplicates
    var uniqueHabits: [Habit] = []
    var seenIds: Set<UUID> = []

    for habit in habits {
      if !seenIds.contains(habit.id) {
        uniqueHabits.append(habit)
        seenIds.insert(habit.id)
      }
    }
    
    let afterDedupeCount = uniqueHabits.count

    // In edit mode, show ALL habits to allow proper reordering
    // (Can't reorder a filtered view - causes index mismatch)
    if editMode == .active {
      return uniqueHabits
    }

    // Determine filter based on selected tab
    let tabName: String
    let filterResult: [Habit]
    
    // Then apply the tab-based filtering (only in normal mode)
    switch selectedStatsTab {
    case 0: // Active
      tabName = "Active"
      filterResult = uniqueHabits.filter { habit in
        // ✅ FIX: Habit is active if it hasn't ended yet (includes future-starting habits)
        let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
        
        // Active = hasn't ended yet (includes habits starting in the future)
        return today <= endDate
      }

    case 1: // Inactive
      tabName = "Inactive"
      filterResult = uniqueHabits.filter { habit in
        // ✅ FIX: Habit is inactive ONLY if its end date has passed
        let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
        
        // Inactive = end date has passed
        return today > endDate
      }

    case 2, 3: // Dummy tabs - show all habits
      tabName = "All"
      filterResult = uniqueHabits

    default:
      tabName = "Default"
      filterResult = uniqueHabits
    }
    
    return filterResult
  }

  // MARK: - Empty State Views

  @ViewBuilder
  private var emptyStateViewForTab: some View {
    switch selectedStatsTab {
    case 0: // Active tab
      HabitEmptyStateView(
        imageName: "Habit-List-Empty-State@4x",
        title: "No active habits",
        subtitle: "All your habits are currently inactive or completed")

    case 1: // Inactive tab
      HabitEmptyStateView(
        imageName: "Today-Habit-List-Empty-State@4x",
        title: "No inactive habits",
        subtitle: "All your habits are currently active")

    default:
      HabitEmptyStateView(
        imageName: "Habit-List-Empty-State@4x",
        title: "No habits found",
        subtitle: "Try adjusting your filters")
    }
  }

  // MARK: - Stats Row

  private var statsRow: some View {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Use habits parameter for immediate updates, not habitsOrder
    // ✅ FIX: Active = hasn't ended yet (includes future-starting habits)
    let activeHabits = habits.filter { habit in
      let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
      return today <= endDate
    }

    // ✅ FIX: Inactive = end date has passed
    let inactiveHabits = habits.filter { habit in
      let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
      return today > endDate
    }

    let tabs = TabItem.createStatsTabs(
      activeCount: activeHabits.count,
      inactiveCount: inactiveHabits.count)

    return UnifiedTabBarView(
      tabs: tabs,
      selectedIndex: selectedStatsTab,
      style: .underline,
      backgroundColor: .surface1)
    { index in
      if index < 2 { // Only allow clicking for first two tabs (Active, Inactive)
        // Haptic feedback when switching tabs
        UISelectionFeedbackGenerator().selectionChanged()
        selectedStatsTab = index
      }
    }
  }

  /// Simplified habit list row for native List
  private func habitListRow(_ habit: Habit) -> some View {
    AddedHabitItem(
      habit: habit,
      isEditMode: editMode == .active,
      onEdit: {
        onEditHabit(habit)
      },
      onDelete: {
        onDeleteHabit(habit)
      },
      onTap: {
        if editMode == .inactive {
          selectedHabit = habit
        }
      },
      onLongPress: {
        if editMode == .inactive {
          // Haptic feedback
          let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
          impactFeedback.impactOccurred()

          // Enter edit mode with animation
          withAnimation(.easeOut(duration: 0.25)) {
            editMode = .active
          }
        }
      })
  }

  /// Handle reordering of habits (native .onMove)
  private func moveHabit(from source: IndexSet, to destination: Int) {
    // Haptic feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    impactFeedback.impactOccurred()

    guard let sourceIndex = source.first else { return }
    
    let habitBeingMoved = filteredHabits[sourceIndex]
    print("🔄 Moving '\(habitBeingMoved.name)' from index \(sourceIndex) to \(destination)")
    
    // Reorder using the filtered habits (which shows ALL habits in edit mode)
    var reorderedHabits = filteredHabits
    reorderedHabits.move(fromOffsets: source, toOffset: destination)
    
    print("✅ New order: \(reorderedHabits.map { $0.name }.joined(separator: ", "))")
    
    // Update state immediately for instant UI feedback
    state.habits = reorderedHabits
    
    // Save to persistent storage using public API
    HabitRepository.shared.saveHabits(reorderedHabits)
  }

  /// Handle deletion of habits (native .onDelete)
  private func deleteHabit(at offsets: IndexSet) {
    for index in offsets {
      let habit = filteredHabits[index]
      onDeleteHabit(habit)
    }
  }

  private func detailItem(icon: String, text: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.appLabelSmallEmphasised)
        .foregroundColor(.secondary)

      Text(text)
        .font(.appLabelSmallEmphasised)
        .foregroundColor(.secondary)
    }
  }

  // MARK: - Helper Methods

  /// Refresh habits data when user pulls down
  private func refreshHabits() async {
    // Refresh habits data from Core Data
    await HabitRepository.shared.loadHabits(force: true)

    // Provide haptic feedback for successful refresh
    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    impactFeedback.impactOccurred()
  }

  /// Debug method to check for duplicate habits
  private func debugCheckForDuplicates() {
    var seenIds: Set<UUID> = []
    var duplicates: [Habit] = []

    for habit in habits {
      if seenIds.contains(habit.id) {
        duplicates.append(habit)
      } else {
        seenIds.insert(habit.id)
      }
    }

    if !duplicates.isEmpty {
      print("⚠️ HabitsTabView: Found \(duplicates.count) duplicate habits:")
      for duplicate in duplicates {
        print("  - ID: \(duplicate.id), Name: \(duplicate.name)")
      }
    } else {
      print("✅ HabitsTabView: No duplicate habits found")
    }
  }
  
  /// Update the count of recently deleted habits
  private func updateRecentlyDeletedCount() async {
    let count = await HabitRepository.shared.countSoftDeletedHabits()
    await MainActor.run {
      recentlyDeletedCount = count
    }
  }
}

#Preview {
  let mockHabits = [
    Habit(
      name: "Read Books",
      description: "Read at least one chapter every day",
      icon: "📚",
      color: .blue,
      habitType: .formation,
      schedule: "Everyday",
      goal: "1 chapter",
      reminder: "No reminder",
      startDate: Date(),
      endDate: nil),
    Habit(
      name: "Exercise",
      description: "Work out for 30 minutes",
      icon: "🏃‍♂️",
      color: .green,
      habitType: .formation,
      schedule: "Weekdays",
      goal: "30 minutes",
      reminder: "No reminder",
      startDate: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 7 days ago
      endDate: Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days from now
    )
  ]

  let mockState = HomeViewState()
  mockState.habits = mockHabits

  return HabitsTabView(
    state: mockState,
    onDeleteHabit: { _ in },
    onEditHabit: { _ in },
    onCreateHabit: { },
    onUpdateHabit: { _ in })
}
