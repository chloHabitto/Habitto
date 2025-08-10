import SwiftUI
import UniformTypeIdentifiers

// MARK: - Jiggle Animation Modifier
struct JiggleAnimationModifier: ViewModifier {
    let isEditMode: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(y: isEditMode ? -2 : 0)
            .rotationEffect(.degrees(isEditMode ? 0.3 : 0))
            .animation(
                isEditMode ? 
                    .easeInOut(duration: 0.3) : 
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
        
        let fromIndex = habitsOrder.firstIndex(of: draggedHabit)
        guard let fromIndex = fromIndex else { return false }
        
        // Use the insertion index if available, otherwise fall back to the item's current position
        let toIndex: Int
        if let insertionIndex = insertionIndex {
            toIndex = insertionIndex
        } else {
            toIndex = habitsOrder.firstIndex(of: item) ?? fromIndex
        }
        
        guard fromIndex != toIndex else { return false }
        
        // Haptic feedback for successful drop
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Reorder the habits with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            var newOrder = habitsOrder
            newOrder.remove(at: fromIndex)
            
            // Adjust insertion index if we're moving an item from before the insertion point
            let adjustedToIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
            newOrder.insert(draggedHabit, at: adjustedToIndex)
            habitsOrder = newOrder
        }
        
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
           let currentIndex = habitsOrder.firstIndex(of: item) {
            
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
                    HStack {
                        statsRow
                            .padding(.horizontal, 0)
                            .padding(.top, 2)
                            .padding(.bottom, 0)
                        
                        Spacer()
                        
                        if isEditMode {
                            Button("Done") {
                                withAnimation(.easeInOut(duration: 0.3)) {
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
                    }
                )
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if habits.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.circle")
                                .font(.appDisplaySmall)
                                .foregroundColor(.secondary)
                            
                            Text("No habits yet")
                                .font(.appButtonText2)
                                .foregroundColor(.secondary)
                            
                            Text("Create your first habit to get started")
                                .font(.appBodyMedium)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .padding(.horizontal, 20)
                    } else {
                        // Reorder instructions when in edit mode
                        if isEditMode {
                            HStack {
                                Spacer()
                                HStack {
                                    Image(systemName: "hand.draw.fill")
                                        .foregroundColor(.accentColor)
                                    Text("Drag habits to reorder")
                                        .font(.appBodySmall)
                                        .foregroundColor(.text04)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        LazyVStack(spacing: 12) {
                            // Enhanced insertion lines for better visual feedback
                            if isEditMode && insertionIndex != nil && draggedHabit != nil {
                                if insertionIndex == 0 {
                                    // Top insertion line for dragging to the very beginning
                                    HStack {
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(height: 4)
                                            .frame(maxWidth: .infinity)
                                            .shadow(color: .accentColor.opacity(0.6), radius: 3)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 2)
                                                    .stroke(Color.white, lineWidth: 1)
                                            )
                                    }
                                    .padding(.horizontal, 16)
                                    .animation(.easeInOut(duration: 0.15), value: insertionIndex)
                                } else if insertionIndex == habitsOrder.count {
                                    // Bottom insertion line for dragging to the very end
                                    HStack {
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(height: 4)
                                            .frame(maxWidth: .infinity)
                                            .shadow(color: .accentColor.opacity(0.6), radius: 3)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 2)
                                                    .stroke(Color.white, lineWidth: 1)
                                            )
                                    }
                                    .padding(.horizontal, 16)
                                    .animation(.easeInOut(duration: 0.15), value: insertionIndex)
                                }
                            }
                            
                            ForEach(Array(filteredHabits.enumerated()), id: \.element.id) { index, habit in
                                VStack(spacing: 0) {
                                    // Insertion line between items when dragging
                                    if isEditMode && insertionIndex != nil && draggedHabit != nil && insertionIndex == index {
                                        HStack {
                                            Rectangle()
                                                .fill(Color.accentColor)
                                                .frame(height: 4)
                                                .frame(maxWidth: .infinity)
                                                .shadow(color: .accentColor.opacity(0.6), radius: 3)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                        .padding(.horizontal, 16)
                                        .animation(.easeInOut(duration: 0.15), value: insertionIndex)
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
                        }
                        .padding(.top, isEditMode ? 8 : 0) // Add top padding when in edit mode
                        .animation(.easeInOut(duration: 0.3), value: isEditMode)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 20)
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
        .onDisappear {
            // Clean up timer to prevent memory leaks
            dragUpdateTimer?.invalidate()
            dragUpdateTimer = nil
        }

    }
    

    
    private var filteredHabits: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // First, deduplicate habits by ID to prevent UI duplicates
        var uniqueHabits: [Habit] = []
        var seenIds: Set<UUID> = []
        
        for habit in habitsOrder {
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
                    .animation(.easeInOut(duration: 0.3).delay(0.15), value: isEditMode) // Increased delay and duration
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
                    .modifier(JiggleAnimationModifier(isEditMode: isEditMode))
                    .animation(.easeInOut(duration: 0.3), value: isEditMode)
                    .overlay(
                        // Visual feedback when item is being dragged over - only show when not being dragged
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(dragOverItem == habit && draggedHabit != habit ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
                            .animation(.easeInOut(duration: 0.15), value: dragOverItem == habit && draggedHabit != habit)
                    )
                    .scaleEffect(draggedHabit == habit ? 0.98 : 1.0)
                    .opacity(draggedHabit == habit ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: draggedHabit == habit)
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
            items: habitsOrder,
            draggedHabit: $draggedHabit,
            habitsOrder: $habitsOrder,
            dragOverItem: $dragOverItem,
            insertionIndex: $insertionIndex,
            onDragStateUpdate: updateDragState
        )
    }
    
    // Debounced drag state update to prevent blinking
    private func updateDragState(dragOver: Habit?, insertion: Int?) {
        // Cancel existing timer
        dragUpdateTimer?.invalidate()
        
        // Set new timer for debounced update
        dragUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                dragOverItem = dragOver
                insertionIndex = insertion
            }
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
        
        let activeHabits = habitsOrder.filter { habit in
            let startDate = calendar.startOfDay(for: habit.startDate)
            let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            return today >= startDate && today <= endDate
        }
        
        let inactiveHabits = habitsOrder.filter { habit in
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
