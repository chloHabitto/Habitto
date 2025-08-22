import SwiftUI

struct HabitSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedHabit: Habit?
    @EnvironmentObject var coreDataAdapter: CoreDataAdapter
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // All Habits Option - Modern Card Design
                    allHabitsCard
                    
                    // Individual Habits Section
                    if !coreDataAdapter.habits.isEmpty {
                        individualHabitsSection
                    } else {
                        emptyStateCard
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Color.surface.ignoresSafeArea())
            .navigationTitle("Select Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.appBodyMediumEmphasised)
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - All Habits Card
    private var allHabitsCard: some View {
        Button(action: {
            selectedHabit = nil
            dismiss()
        }) {
            HStack(spacing: 16) {
                // Icon with gradient background
                allHabitsIcon
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("All Habits")
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.text01)
                    
                    Text("Overall progress and insights")
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                }
                
                Spacer()
                
                // Selection indicator
                allHabitsSelectionIndicator
            }
            .padding(20)
            .background(allHabitsCardBackground)
            .shadow(
                color: selectedHabit == nil ? Color.primary.opacity(0.1) : Color.black.opacity(0.05),
                radius: selectedHabit == nil ? 12 : 8,
                x: 0,
                y: selectedHabit == nil ? 6 : 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(selectedHabit == nil ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedHabit == nil)
        .contentShape(Rectangle())
        .highPriorityGesture(TapGesture().onEnded { _ in
            selectedHabit = nil
            dismiss()
        })
    }
    
    private var allHabitsIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.15))
                .frame(width: 30, height: 30)
            
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }
    
    private var allHabitsSelectionIndicator: some View {
        Group {
            if selectedHabit == nil {
                ZStack {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                Circle()
                    .stroke(Color.outline3.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
    }
    
    private var allHabitsCardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        selectedHabit == nil ? Color.primary.opacity(0.3) : Color.outline3.opacity(0.2),
                        lineWidth: selectedHabit == nil ? 2 : 1
                    )
            )
    }
    
    // MARK: - Individual Habits Section
    private var individualHabitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            individualHabitsHeader
            
            // Habits Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 1), spacing: 16) {
                ForEach(coreDataAdapter.habits, id: \.id) { habit in
                    habitCard(for: habit)
                }
            }
        }
    }
    
    private var individualHabitsHeader: some View {
        HStack {
            Text("Individual Habits")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text01)
            
            Spacer()
            
            Text("\(coreDataAdapter.habits.count)")
                .font(.appLabelMedium)
                .foregroundColor(.text03)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.outline3.opacity(0.1))
                )
        }
        .padding(.horizontal, 4)
    }
    
    private func habitCard(for habit: Habit) -> some View {
        HStack(spacing: 16) {
            // Habit Icon with custom background
            habitIcon(for: habit)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name)
                    .font(.appBodyMediumEmphasised)
                    .foregroundColor(.text01)
                    .lineLimit(1)
                
                Text(habit.goal)
                    .font(.appBodySmall)
                    .foregroundColor(.text03)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Selection indicator
            habitSelectionIndicator(for: habit)
        }
        .padding(20)
        .background(habitCardBackground(for: habit))
        .shadow(
            color: selectedHabit?.id == habit.id ? habit.color.opacity(0.1) : Color.black.opacity(0.05),
            radius: selectedHabit?.id == habit.id ? 12 : 8,
            x: 0,
            y: selectedHabit?.id == habit.id ? 6 : 4
        )
        .scaleEffect(selectedHabit?.id == habit.id ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedHabit?.id == habit.id)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedHabit = habit
            dismiss()
        }
        .highPriorityGesture(TapGesture().onEnded { _ in
            selectedHabit = habit
            dismiss()
        })
    }
    
    private func habitIcon(for habit: Habit) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(habit.color.opacity(0.15))
                .frame(width: 30, height: 30)
            
            if habit.icon.hasPrefix("Icon-") {
                // Asset icon
                Image(habit.icon)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(habit.color)
            } else if habit.icon == "None" {
                // No icon selected - show colored rounded rectangle
                RoundedRectangle(cornerRadius: 4)
                    .fill(habit.color)
                    .frame(width: 14, height: 14)
            } else {
                // Emoji or system icon
                Text(habit.icon)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }
    
    private func habitSelectionIndicator(for habit: Habit) -> some View {
        Group {
            if selectedHabit?.id == habit.id {
                ZStack {
                    Circle()
                        .fill(habit.color)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                Circle()
                    .stroke(Color.outline3.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
    }
    
    private func habitCardBackground(for habit: Habit) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        selectedHabit?.id == habit.id ? habit.color.opacity(0.3) : Color.outline3.opacity(0.2),
                        lineWidth: selectedHabit?.id == habit.id ? 2 : 1
                    )
            )
    }
    
    // MARK: - Empty State Card
    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            // Cute illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 8) {
                Text("No habits yet")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.text01)
                
                Text("Create your first habit to see individual progress")
                    .font(.appBodyMedium)
                    .foregroundColor(.text03)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.outline3.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    HabitSelectorView(selectedHabit: .constant(nil))
        .environmentObject(CoreDataAdapter.shared)
}
