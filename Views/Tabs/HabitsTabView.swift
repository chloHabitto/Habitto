import SwiftUI

struct HabitsTabView: View {
    @State private var selectedStatsTab: Int = 0
    @State private var showingPopupForHabit: Habit? = nil
    let habits: [Habit]
    let onToggleHabit: (Habit) -> Void
    let onDeleteHabit: (Habit) -> Void
    let onEditHabit: (Habit) -> Void
    let onCreateHabit: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            VStack(spacing: 0) {
                // First row - My Habits text
                HStack {
                                    Text("My Habits")
                                                    .font(.appTitleLargeEmphasised)
                    .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                
                // Stats row
                statsRow
            }
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
            .frame(alignment: .top)
            .roundedTopBackground()
            
            // Scrollable habits list fills the rest
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
                        LazyVStack(spacing: 12) {
                            ForEach(filteredHabits) { habit in
                                habitDetailRow(habit)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Edit") {
                                            // TODO: Implement edit functionality
                                        }
                                        .tint(.blue)
                                        
                                        Button("Delete") {
                                            onDeleteHabit(habit)
                                        }
                                        .tint(.red)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .roundedTopBackground()
        .onTapGesture {
            // Dismiss popup when tapping outside
            showingPopupForHabit = nil
        }
    }
    
    private var filteredHabits: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        switch selectedStatsTab {
        case 0: // Active
            return habits.filter { habit in
                // Check if habit is currently active (within its period)
                let startDate = calendar.startOfDay(for: habit.startDate)
                let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
                
                // Habit is active if today is within its period
                return today >= startDate && today <= endDate
            }
        case 1: // Inactive
            return habits.filter { habit in
                // Check if habit is currently inactive (outside its period)
                let startDate = calendar.startOfDay(for: habit.startDate)
                let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
                
                // Habit is inactive if today is outside its period
                return today < startDate || today > endDate
            }
        case 2, 3: // Dummy tabs - show all habits
            return habits
        default:
            return habits
        }
    }
    
    private func habitDetailRow(_ habit: Habit) -> some View {
        AddedHabitItem(
            title: habit.name,
            description: habit.description.isEmpty ? "No description" : habit.description,
            selectedColor: habit.color,
            icon: habit.icon,
            schedule: habit.schedule,
            goal: habit.goal
        )
        .onTapGesture {
            onToggleHabit(habit)
        }
        .overlay(
            // Popup menu
            Group {
                if showingPopupForHabit?.id == habit.id {
                    VStack(alignment: .trailing, spacing: 0) {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .leading, spacing: 0) {
                                popupMenuItem(
                                    icon: "pencil",
                                    text: "Edit",
                                    color: .primary,
                                    action: {
                                        onEditHabit(habit)
                                        showingPopupForHabit = nil
                                    }
                                )
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color(.systemGray4))
                                
                                popupMenuItem(
                                    icon: "trash",
                                    text: "Delete",
                                    color: .red,
                                    action: {
                                        onDeleteHabit(habit)
                                        showingPopupForHabit = nil
                                    }
                                )
                            }
                            .frame(width: 120)
                            .padding(.leading, 8)
                            .background(
                                Color.white.opacity(0.95)
                                    .blur(radius: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .padding(.trailing, 16)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
        )
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
    
    private func popupMenuItem(icon: String, text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.appBodyLarge)
                Text(text)
                    .font(.appBodyLarge)
                    .lineSpacing(3)
            }
            .foregroundColor(color)
            .padding(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
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
        
        let stats = [
            ("Active", activeHabits.count),
            ("Inactive", inactiveHabits.count),
            ("", 0), // Dummy third tab
            ("", 0) // Dummy fourth tab
        ]
        
        return HStack(spacing: 0) {
            ForEach(0..<stats.count, id: \.self) { idx in
                statsTabButton(for: idx, stats: stats)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
    
    @ViewBuilder
    private func statsTabButton(for idx: Int, stats: [(String, Int)]) -> some View {
        VStack(spacing: 0) {
            Button(action: { 
                if idx < 2 { // Only allow clicking for first two tabs (Active, Inactive)
                    selectedStatsTab = idx 
                }
            }) {
                HStack(spacing: 4) {
                    Text(stats[idx].0)
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(selectedStatsTab == idx ? .text03 : .text04)
                        .opacity(idx >= 2 ? 0 : 1) // Make third and fourth tab text invisible
                    Text("\(stats[idx].1)")
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(selectedStatsTab == idx ? .text03 : .text04)
                        .opacity(idx >= 2 ? 0 : 1) // Make third and fourth tab text invisible
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: idx >= 2 ? .infinity : nil) // Expand third and fourth tabs
            .disabled(idx >= 2) // Disable clicking for third and fourth tabs
            
            // Bottom stroke for each tab
            Rectangle()
                .fill(selectedStatsTab == idx ? .text03 : .divider)
                .frame(height: 3)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.2), value: selectedStatsTab)
        }
    }
}

 
