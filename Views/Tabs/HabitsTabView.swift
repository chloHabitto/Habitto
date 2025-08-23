import SwiftUI
import UniformTypeIdentifiers

// MARK: - Jiggle Animation Modifier
struct JiggleAnimationModifier: ViewModifier {
    let isEditMode: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(y: isEditMode ? -1 : 0) // Reduced from -2 to -1 for subtler movement
            .rotationEffect(.degrees(isEditMode ? 0.2 : 0)) // Reduced from 0.3 to 0.2 for subtler rotation
            .animation(
                isEditMode ? 
                    .easeInOut(duration: 0.25) : // Reduced from 0.3 to 0.25
                    .easeInOut(duration: 0.2),
                value: isEditMode
            )
    }
}

// MARK: - Drop View Delegate
struct DropViewDelegate: DropDelegate {
    let item: Habit
    let items: [Habit]
    @Binding var draggedHabit: Habit?
    @Binding var habitsOrder: [Habit]
    @Binding var dragOverItem: Habit?
    @Binding var insertionIndex: Int?
    
    // Reference to parent view for debounced updates
    let onDragStateUpdate: (Habit?, Int?) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedHabit = draggedHabit else { return false }
        
        // Find the actual indices in the full habitsOrder array
        let fromIndex = habitsOrder.firstIndex(of: draggedHabit)
        let toIndex = insertionIndex
        
        guard let fromIndex = fromIndex,
              let toIndex = toIndex,
              fromIndex != toIndex else { 
            print("❌ Drop failed: fromIndex=\(fromIndex?.description ?? "nil"), toIndex=\(toIndex?.description ?? "nil")")
            return false 
        }
        
        print("✅ Dropping habit '\(draggedHabit.name)' from index \(fromIndex) to index \(toIndex)")
        
        // Haptic feedback for successful drop
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Reorder the habits with animation
        withAnimation(.easeOut(duration: 0.25)) {
            var newOrder = habitsOrder
            newOrder.remove(at: fromIndex)
            
            // Adjust insertion index if we're moving an item from before the insertion point
            let adjustedToIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
            newOrder.insert(draggedHabit, at: adjustedToIndex)
            habitsOrder = newOrder
        }
        
        print("✅ Habits reordered successfully. New order: \(habitsOrder.map { $0.name })")
        
        // Clear the dragged habit and drag over state
        self.draggedHabit = nil
        self.dragOverItem = nil
        self.insertionIndex = nil
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Prevent rapid state changes that could cause blinking
        guard dragOverItem != item else { return }
        
        // Calculate insertion index based on drop position
        if let _ = draggedHabit,
           let currentIndex = items.firstIndex(of: item) {
            
            // Determine if we should insert before or after the current item
            // based on the drop position relative to the item's center
            let itemHeight: CGFloat = 90
            let threshold = itemHeight / 2
            
            let newInsertionIndex: Int
            if info.location.y > threshold {
                // If drop is in lower half of item, insert after
                newInsertionIndex = currentIndex + 1
            } else {
                // If drop is in upper half of item, insert before
                newInsertionIndex = currentIndex
            }
            
            // Use debounced update to prevent rapid changes
            onDragStateUpdate(item, newInsertionIndex)
        }
    }
    
    func dropExited(info: DropInfo) {
        // Clear the drag over state when leaving an item
        if dragOverItem == item {
            onDragStateUpdate(nil, nil)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Provide real-time feedback during drag
        return DropProposal(operation: .move)
    }
}

struct HabitsTabView: View {
    @State private var selectedStatsTab: Int = 0
    @State private var selectedHabit: Habit? = nil
    @State private var isEditMode: Bool = false
    @State private var draggedHabit: Habit? = nil
    @State private var habitsOrder: [Habit]
    @State private var dragOverItem: Habit? = nil
    @State private var insertionIndex: Int? = nil
    
    // Debounce timer for drag state updates
    @State private var dragUpdateTimer: Timer?

    let habits: [Habit]
    let onDeleteHabit: (Habit) -> Void
    let onEditHabit: (Habit) -> Void
    let onCreateHabit: () -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    
    // Custom initializer with default value for onUpdateHabit
    init(
        habits: [Habit],
        onDeleteHabit: @escaping (Habit) -> Void,
        onEditHabit: @escaping (Habit) -> Void,
        onCreateHabit: @escaping () -> Void,
        onUpdateHabit: ((Habit) -> Void)? = nil
    ) {
        self.habits = habits
        self.onDeleteHabit = onDeleteHabit
        self.onEditHabit = onEditHabit
        self.onCreateHabit = onCreateHabit
        self.onUpdateHabit = onUpdateHabit
        self._habitsOrder = State(initialValue: habits)
    }
    
    var body: some View {
        WhiteSheetContainer(
            title: "Habits",
            headerContent: {
                AnyView(
                    VStack(spacing: 0) {
                        // Stats row with tabs - now can expand to full width
                        statsRow
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 0)
                            .padding(.top, 2)
                            .padding(.bottom, 0)
                        
                        // Done button in its own row when in edit mode
                        if isEditMode {
                            HStack {
                                Spacer()
                                Button("Done") {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        isEditMode = false
                                        // Clear drag states when exiting edit mode
                                        draggedHabit = nil
                                        dragOverItem = nil
                                        insertionIndex = nil
                                    }
                                }
                                .font(.appButtonText2)
                                .foregroundColor(.accentColor)
                                .padding(.trailing, 20)
                            }
                            .padding(.top, 8)
                        }
                    }
                )
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if habits.isEmpty {
                        // No habits created in the app at all
                        HabitEmptyStateView.noHabitsYet()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if filteredHabits.isEmpty {
                        // No habits for the selected tab
                        emptyStateViewForTab
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredHabits.enumerated()), id: \.element.id) { index, habit in
                                VStack(spacing: 0) {
                                    // Show insertion line above the item where it will be placed
                                    if isEditMode && insertionIndex != nil && draggedHabit != nil && insertionIndex == index {
                                        HStack {
                                            Rectangle()
                                                .fill(Color.accentColor)
                                                .frame(height: 4)
                                                .frame(maxWidth: .infinity)
                                                .shadow(color: .accentColor.opacity(0.4), radius: 2)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4) // Add the requested 4pt vertical padding
                                        .animation(.easeOut(duration: 0.2), value: insertionIndex)
                                    }
                                    
                                    habitDetailRow(habit)
                                        .onDrag {
                                            if isEditMode {
                                                // Haptic feedback when starting drag
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                impactFeedback.impactOccurred()
                                                
                                                draggedHabit = habit
                                                return NSItemProvider(object: habit.id.uuidString as NSString)
                                            }
                                            return NSItemProvider()
                                        } preview: {
                                            habitDetailRow(habit)
                                                .scaleEffect(0.85)
                                                .opacity(0.95)
                                                .shadow(radius: 12, x: 0, y: 4)
                                                .background(Color.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .onDrop(of: [.text], delegate: createDropDelegate(for: habit))
                                        .id("habit-\(habit.id)-\(index)") // Performance optimization: Stable ID
                                }
                            }
                            
                            // Show insertion line at the very end if dragging to the bottom
                            if isEditMode && insertionIndex != nil && draggedHabit != nil && insertionIndex == filteredHabits.count {
                                HStack {
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(height: 4)
                                        .frame(maxWidth: .infinity)
                                        .shadow(color: .accentColor.opacity(0.4), radius: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(Color.white, lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4) // Add the requested 4pt vertical padding
                                .animation(.easeOut(duration: 0.2), value: insertionIndex)
                            }
                            
                            // Add a drop zone at the bottom for easier reordering to the end
                            if isEditMode {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 40) // Reduced height to be less intrusive
                                    .frame(maxWidth: .infinity)
                                    .onDrop(of: [.text], delegate: createBottomDropDelegate())
                                    .overlay(
                                        // Visual feedback when dragging over the bottom drop zone
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(dragOverItem == nil && draggedHabit != nil && insertionIndex == filteredHabits.count ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                                            .animation(.easeOut(duration: 0.15), value: dragOverItem == nil && draggedHabit != nil && insertionIndex == filteredHabits.count)
                                    )
                            }
                        }
                        .padding(.top, isEditMode ? 8 : 0) // Add top padding when in edit mode
                        .padding(.bottom, 40) // Add bottom padding to the habits list
                        .animation(.easeOut(duration: 0.25), value: isEditMode)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
            }
            .refreshable {
                // Refresh habits data when user pulls down
                await refreshHabits()
            }


        }
        .fullScreenCover(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, onUpdateHabit: onUpdateHabit, selectedDate: Date(), onDeleteHabit: onDeleteHabit)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            // Swipe right to dismiss (like back button)
                            if value.translation.width > 100 && abs(value.translation.height) < 100 {
                                selectedHabit = nil
                            }
                        }
                )
        }
        .onAppear {
            // Debug: Check for duplicate habits
            debugCheckForDuplicates()
        }
        .onChange(of: habits) { oldHabits, newHabits in
            // Sync local habitsOrder with incoming habits to handle deletions
            print("🔄 HabitsTabView: habits parameter changed from \(oldHabits.count) to \(newHabits.count)")
            habitsOrder = newHabits
            print("🔄 HabitsTabView: habitsOrder updated to \(habitsOrder.count)")
        }
        .onChange(of: habitsOrder) { oldOrder, newOrder in
            // Notify parent when habits are reordered
            if oldOrder != newOrder && onUpdateHabit != nil {
                print("🔄 HabitsTabView: Habits reordered, notifying parent")
                // Update each habit in the new order to trigger parent updates
                for habit in newOrder {
                    onUpdateHabit?(habit)
                }
            }
        }
        .onDisappear {
            // Clean up timer to prevent memory leaks
            dragUpdateTimer?.invalidate()
            dragUpdateTimer = nil
        }

    }
    

    
    private var filteredHabits: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Use habitsOrder when in edit mode to show reordering changes immediately
        // Use the habits parameter for immediate updates when not in edit mode
        let habitsToFilter = isEditMode ? habitsOrder : habits
        
        // First, deduplicate habits by ID to prevent UI duplicates
        var uniqueHabits: [Habit] = []
        var seenIds: Set<UUID> = []
        
        for habit in habitsToFilter {
            if !seenIds.contains(habit.id) {
                uniqueHabits.append(habit)
                seenIds.insert(habit.id)
            }
        }
        
        // Then apply the tab-based filtering
        switch selectedStatsTab {
        case 0: // Active
            return uniqueHabits.filter { habit in
                // Check if habit is currently active (within its period)
                let startDate = calendar.startOfDay(for: habit.startDate)
                let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
                
                // Habit is active if today is within its period
                return today >= startDate && today <= endDate
            }
        case 1: // Inactive
            return uniqueHabits.filter { habit in
                // Check if habit is currently inactive (outside its period)
                let startDate = calendar.startOfDay(for: habit.startDate)
                let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
                
                // Habit is inactive if today is outside its period
                return today < startDate || today > endDate
            }
        case 2, 3: // Dummy tabs - show all habits
            return uniqueHabits
        default:
            return uniqueHabits
        }
    }
    
    // MARK: - Empty State Views
    @ViewBuilder
    private var emptyStateViewForTab: some View {
        switch selectedStatsTab {
        case 0: // Active tab
            HabitEmptyStateView(
                imageName: "Habit-List-Empty-State@4x",
                title: "No active habits",
                subtitle: "All your habits are currently inactive or completed"
            )
        case 1: // Inactive tab
            HabitEmptyStateView(
                imageName: "Today-Habit-List-Empty-State@4x",
                title: "No inactive habits",
                subtitle: "All your habits are currently active"
            )
        default:
            HabitEmptyStateView(
                imageName: "Habit-List-Empty-State@4x",
                title: "No habits found",
                subtitle: "Try adjusting your filters"
            )
        }
    }
    
    private func habitDetailRow(_ habit: Habit) -> some View {
        Group {
            if isEditMode {
                // Edit mode: Delete button and habit item in HStack
                HStack(spacing: 16) {
                    Button(action: {
                        onDeleteHabit(habit)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            .background(Color.white, in: Circle())
                            .shadow(radius: 2)
                    }
                    .frame(width: 24, height: 24) // Ensure consistent touch target
                    .scaleEffect(isEditMode ? 1.0 : 0.0) // Scale animation
                    .opacity(isEditMode ? 1.0 : 0.0) // Fade animation
                    .animation(.easeOut(duration: 0.25).delay(0.1), value: isEditMode) // Improved timing and reduced delay
                    .background(
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 48, height: 48)
                    )
                    
                    // Main habit item with jiggle animation and drag feedback
                    AddedHabitItem(
                        habit: habit,
                        isEditMode: isEditMode,
                        onEdit: {
                            onEditHabit(habit)
                        },
                        onDelete: {
                            onDeleteHabit(habit)
                        },
                        onTap: {
                            if !isEditMode {
                                selectedHabit = habit
                            }
                        },
                        onLongPress: {
                            print("🔍 HabitsTabView: Long press detected for habit: \(habit.name)")
                            if !isEditMode {
                                print("🔍 HabitsTabView: Entering edit mode")
                                
                                // Haptic feedback first
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                // Enter edit mode with animation
                                withAnimation(.easeOut(duration: 0.25)) {
                                    isEditMode = true
                                    // Clear any existing drag states
                                    draggedHabit = nil
                                    dragOverItem = nil
                                    insertionIndex = nil
                                }
                            } else {
                                print("🔍 HabitsTabView: Already in edit mode")
                            }
                        }
                    )
                    .modifier(JiggleAnimationModifier(isEditMode: isEditMode))
                    .animation(.easeOut(duration: 0.25), value: isEditMode)
                    .overlay(
                        // Visual feedback when item is being dragged over - only show when not being dragged
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(dragOverItem == habit && draggedHabit != habit ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
                            .animation(.easeOut(duration: 0.15), value: dragOverItem == habit && draggedHabit != habit)
                    )
                    .scaleEffect(draggedHabit == habit ? 0.98 : 1.0)
                    .opacity(draggedHabit == habit ? 0.8 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: draggedHabit == habit)
                }
            } else {
                // Normal mode: Just the habit item
                AddedHabitItem(
                    habit: habit,
                    isEditMode: isEditMode,
                    onEdit: {
                        onEditHabit(habit)
                    },
                    onDelete: {
                        onDeleteHabit(habit)
                    },
                    onTap: {
                        if !isEditMode {
                            selectedHabit = habit
                        }
                    },
                    onLongPress: {
                        print("🔍 HabitsTabView: Long press detected for habit: \(habit.name)")
                        if !isEditMode {
                            print("🔍 HabitsTabView: Entering edit mode")
                            
                            // Haptic feedback first
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            // Enter edit mode with animation
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isEditMode = true
                                // Clear any existing drag states
                                draggedHabit = nil
                                dragOverItem = nil
                                insertionIndex = nil
                            }
                        } else {
                            print("🔍 HabitsTabView: Already in edit mode")
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Helper function to create drop delegate
    private func createDropDelegate(for habit: Habit) -> DropViewDelegate {
        DropViewDelegate(
            item: habit,
            items: filteredHabits, // Use filteredHabits instead of habitsOrder for consistency
            draggedHabit: $draggedHabit,
            habitsOrder: $habitsOrder,
            dragOverItem: $dragOverItem,
            insertionIndex: $insertionIndex,
            onDragStateUpdate: updateDragState
        )
    }
    
    // Helper function to create drop delegate for the bottom drop zone
    private func createBottomDropDelegate() -> BottomDropDelegate {
        BottomDropDelegate(
            items: filteredHabits,
            draggedHabit: $draggedHabit,
            habitsOrder: $habitsOrder,
            dragOverItem: $dragOverItem,
            insertionIndex: $insertionIndex,
            onDragStateUpdate: updateDragState
        )
    }
    
    // MARK: - Bottom Drop Delegate
    struct BottomDropDelegate: DropDelegate {
        let items: [Habit]
        @Binding var draggedHabit: Habit?
        @Binding var habitsOrder: [Habit]
        @Binding var dragOverItem: Habit?
        @Binding var insertionIndex: Int?
        let onDragStateUpdate: (Habit?, Int?) -> Void
        
        func performDrop(info: DropInfo) -> Bool {
            guard let draggedHabit = draggedHabit else { return false }
            
            // Find the actual index in the full habitsOrder array
            let fromIndex = habitsOrder.firstIndex(of: draggedHabit)
            let toIndex = items.count // Always insert at the end
            
            guard let fromIndex = fromIndex,
                  fromIndex != toIndex else { return false }
            
            // Haptic feedback for successful drop
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Reorder the habits with animation
            withAnimation(.easeOut(duration: 0.25)) {
                var newOrder = habitsOrder
                newOrder.remove(at: fromIndex)
                newOrder.append(draggedHabit) // Append to the end
                habitsOrder = newOrder
            }
            
            // Clear the dragged habit and drag over state
            self.draggedHabit = nil
            self.dragOverItem = nil
            self.insertionIndex = nil
            
            return true
        }
        
        func dropEntered(info: DropInfo) {
            // Set insertion index to the end of the list
            onDragStateUpdate(nil, items.count)
        }
        
        func dropExited(info: DropInfo) {
            // Clear the drag over state
            onDragStateUpdate(nil, nil)
        }
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            return DropProposal(operation: .move)
        }
    }
    
    // Debounced drag state update to prevent blinking
    private func updateDragState(dragOver: Habit?, insertion: Int?) {
        // Cancel existing timer
        dragUpdateTimer?.invalidate()
        
        print("🔄 Drag state update: dragOver=\(dragOver?.name ?? "nil"), insertion=\(insertion?.description ?? "nil")")
        
        // Set new timer for debounced update - reduced from 0.05 to 0.03 for more responsiveness
        dragUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.15)) {
                dragOverItem = dragOver
                insertionIndex = insertion
            }
            print("✅ Drag state updated: dragOverItem=\(dragOver?.name ?? "nil"), insertionIndex=\(insertion?.description ?? "nil")")
        }
    }
    
    // Refresh habits data when user pulls down
    private func refreshHabits() async {
        // Refresh habits data from Core Data
        await MainActor.run {
            // Force reload habits from Core Data
            CoreDataAdapter.shared.loadHabits(force: true)
            
            // Update the local habits order to match the refreshed data
            let refreshedHabits = CoreDataAdapter.shared.habits
            habitsOrder = refreshedHabits
            
            // Provide haptic feedback for successful refresh
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    // Debug method to check for duplicate habits
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
    
    // MARK: - Stats Row
    private var statsRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Use habits parameter for immediate updates, not habitsOrder
        let activeHabits = habits.filter { habit in
            let startDate = calendar.startOfDay(for: habit.startDate)
            let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            return today >= startDate && today <= endDate
        }
        
        let inactiveHabits = habits.filter { habit in
            let startDate = calendar.startOfDay(for: habit.startDate)
            let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            return today < startDate || today > endDate
        }
        
        let tabs = TabItem.createStatsTabs(activeCount: activeHabits.count, inactiveCount: inactiveHabits.count)
        
        return UnifiedTabBarView(
            tabs: tabs,
            selectedIndex: selectedStatsTab,
            style: .underline
        ) { index in
            if index < 2 { // Only allow clicking for first two tabs (Active, Inactive)
                // Haptic feedback when switching tabs
                UISelectionFeedbackGenerator().selectionChanged()
                selectedStatsTab = index
            }
        }
    }
}

#Preview {
    HabitsTabView(
        habits: [
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
                endDate: nil,
                isCompleted: false,
                streak: 5
            ),
            Habit(
                name: "Exercise",
                description: "Work out for 30 minutes",
                icon: "🏃‍♂️",
                color: .green,
                habitType: .formation,
                schedule: "Weekdays",
                goal: "30 minutes",
                reminder: "No reminder",
                startDate: Date().addingTimeInterval(-7*24*60*60), // 7 days ago
                endDate: Date().addingTimeInterval(7*24*60*60), // 7 days from now
                isCompleted: false,
                streak: 3
            )
        ],
        onDeleteHabit: { _ in },
        onEditHabit: { _ in },
        onCreateHabit: { },
        onUpdateHabit: { _ in }
    )
}
