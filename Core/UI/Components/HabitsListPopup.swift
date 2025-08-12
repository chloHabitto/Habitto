import SwiftUI

struct HabitsListPopup: View {
    let habits: [Habit]
    let selectedHabit: Habit?
    let showingHabitsList: Bool
    let onHabitSelected: (Habit?) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HabitsPopupHeader(onDismiss: onDismiss)
                
                // Habits list
                HabitsPopupList(
                    habits: habits,
                    selectedHabit: selectedHabit,
                    onHabitSelected: onHabitSelected
                )
            }
            .background(Color.surface)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Habits Popup Header
struct HabitsPopupHeader: View {
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Text("Active Habits")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.onPrimaryContainer)
            
            Spacer()
            
            Button("Done") {
                onDismiss()
            }
            .font(.appBodyMedium)
            .foregroundColor(.primary)
        }
        .padding(20)
        .background(Color.surface)
    }
}

// MARK: - Habits Popup List
struct HabitsPopupList: View {
    let habits: [Habit]
    let selectedHabit: Habit?
    let onHabitSelected: (Habit?) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Overall option (always first)
                OverallOptionRow(
                    isSelected: selectedHabit == nil,
                    onSelected: { onHabitSelected(nil) }
                )
                
                // Individual habits
                ForEach(habits, id: \.id) { habit in
                    HabitRowView(
                        habit: habit,
                        isSelected: selectedHabit?.id == habit.id,
                        onSelected: { onHabitSelected(habit) }
                    )
                }
            }
            .padding(.vertical, 20)
        }
        .onAppear {
            print("🔍 HABITS POPUP DEBUG - Total habits: \(habits.count)")
            for habit in habits {
                print("🔍 HABITS POPUP DEBUG - Habit: \(habit.name), Type: \(habit.habitType)")
            }
        }
    }
}

// MARK: - Overall Option Row
struct OverallOptionRow: View {
    let isSelected: Bool
    let onSelected: () -> Void
    
    var body: some View {
        Button(action: onSelected) {
            HStack(spacing: 16) {
                // Overall icon - same style as habit icons
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
                
                // Overall text
                Text("Overall")
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                    .lineLimit(1)
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding(16)
            .background(isSelected ? Color.primary.opacity(0.05) : Color.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary : Color.outline3, lineWidth: isSelected ? 2 : 1)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Individual Habit Row
struct HabitRowView: View {
    let habit: Habit
    let isSelected: Bool
    let onSelected: () -> Void
    
    var body: some View {
        Button(action: onSelected) {
            HStack(spacing: 16) {
                // Habit icon
                HabitIconView(habit: habit)
                    .frame(width: 40, height: 40)
                
                // Habit details in VStack
                VStack(alignment: .leading, spacing: 4) {
                    // Habit type indicator
                    HabitTypeIndicator(habit: habit)
                    
                    // Habit name
                    Text(habit.name)
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding(16)
            .background(isSelected ? Color.primary.opacity(0.05) : Color.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary : Color.outline3, lineWidth: isSelected ? 2 : 1)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Habit Type Indicator
struct HabitTypeIndicator: View {
    let habit: Habit
    
    var body: some View {
        let typeText = habit.habitType == .formation ? "Habit Building" : "Habit Breaking"
        let typeColor = habit.habitType == .formation ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        
        return Text(typeText)
            .font(.appLabelSmall)
            .foregroundColor(.text02)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor)
            )
    }
}
