import SwiftUI

struct CreateHabitStep2View: View {
    let step1Data: (String, String, String, Color, HabitType)
    let habitToEdit: Habit?
    let goBack: () -> Void
    let onSave: (Habit) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func isToday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    @State private var schedule: String = "Everyday"
    @State private var goal: String = "1 time"
    @State private var reminder: String = "No reminder"
    @State private var reminders: [ReminderItem] = []
    @State private var startDate: Date = Date()
    @State private var endDate: Date? = nil
    @State private var showingScheduleSheet = false
    @State private var showingGoalSheet = false
    @State private var showingReminderSheet = false
    @State private var showingPeriodSheet = false
    @State private var isSelectingStartDate = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Cancel button (same as Step 1)
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .font(.title)
                .foregroundColor(Color(red: 0.15, green: 0.23, blue: 0.42))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Progress indicator (both filled for Step 2)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.primaryDim)
                    .frame(width: 32, height: 8)
                Rectangle()
                    .fill(.primaryDim)
                    .frame(width: 32, height: 8)
            }
            .frame(width: 64, height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Header (same as Step 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("Create Habit")
                    .font(.headline)
                    .foregroundColor(.text01)
                Text("Let's get started!")
                    .font(.title)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Schedule
                    Button(action: {
                        showingScheduleSheet = true
                    }) {
                        HStack {
                            Text("Schedule")
                                .font(.title)
                                .foregroundColor(.text01)
                            Spacer()
                            Text(schedule)
                                .font(.body)
                                .foregroundColor(.text04)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.primaryDim)
                        }
                        .selectionRowStyle()
                    }
                    .sheet(isPresented: $showingScheduleSheet) {
                        ScheduleBottomSheet(
                            onClose: { showingScheduleSheet = false },
                            onScheduleSelected: { selectedSchedule in
                                schedule = selectedSchedule
                                showingScheduleSheet = false
                            }
                        )
                    }
                    
                    // Goal
                    Button(action: {
                        showingGoalSheet = true
                    }) {
                        HStack {
                            Text("Goal")
                                .font(.title2)
                                .foregroundColor(.text01)
                            Spacer()
                            Text(goal)
                                .font(.body)
                                .foregroundColor(.text04)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.primaryDim)
                        }
                        .selectionRowStyle()
                    }
                    .sheet(isPresented: $showingGoalSheet) {
                        GoalBottomSheet(
                            onClose: { showingGoalSheet = false },
                            onGoalSelected: { selectedGoal in
                                goal = selectedGoal
                                showingGoalSheet = false
                            }
                        )
                    }
                    
                    // Reminder
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reminder")
                                .font(.title2)
                                .foregroundColor(.text01)
                            Spacer()
                            Text(reminders.isEmpty ? "Add" : "\(reminders.filter { $0.isActive }.count) reminder\(reminders.filter { $0.isActive }.count == 1 ? "" : "s")")
                                .font(.body)
                                .foregroundColor(.text04)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.primaryDim)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingReminderSheet = true
                        }
                        
                        if !reminders.isEmpty {
                            Divider()
                                .background(.outline)
                                .padding(.vertical, 4)
                            
                            VStack(spacing: 4) {
                                ForEach(reminders.filter { $0.isActive }) { reminder in
                                    HStack {
                                        Text(formatTime(reminder.time))
                                            .font(.body)
                                            .foregroundColor(.text01)
                                        Spacer()
                                        Text("Active")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.secondaryContainer)
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .selectionRowStyle()
                    .sheet(isPresented: $showingReminderSheet) {
                        ReminderBottomSheet(
                            onClose: { showingReminderSheet = false },
                            onReminderSelected: { selectedReminder in
                                reminder = selectedReminder
                                showingReminderSheet = false
                            },
                            initialReminders: reminders,
                            onRemindersUpdated: { updatedReminders in
                                reminders = updatedReminders
                                let activeReminders = updatedReminders.filter { $0.isActive }
                                if !activeReminders.isEmpty {
                                    reminder = "\(activeReminders.count) reminder\(activeReminders.count == 1 ? "" : "s")"
                                } else {
                                    reminder = "No reminder"
                                }
                                showingReminderSheet = false
                            }
                        )
                    }
                    
                    // Period
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Period")
                            .font(.title2)
                            .foregroundColor(.primary)
                        HStack(spacing: 12) {
                            // Start Date
                            Button(action: {
                                isSelectingStartDate = true
                                showingPeriodSheet = true
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start Date")
                                        .font(.body)
                                        .foregroundColor(.text05)
                                    Text(isToday(startDate) ? "Today" : formatDate(startDate))
                                        .font(.body)
                                        .foregroundColor(.text04)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .inputFieldStyle()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            // End Date
                            Button(action: {
                                isSelectingStartDate = false
                                showingPeriodSheet = true
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("End Date")
                                        .font(.body)
                                        .foregroundColor(.text05)
                                    Text(endDate == nil ? "Not Selected" : formatDate(endDate!))
                                        .font(.body)
                                        .foregroundColor(.text04)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .inputFieldStyle()
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .selectionRowStyle()
                    .sheet(isPresented: $showingPeriodSheet) {
                        PeriodBottomSheet(
                            isSelectingStartDate: isSelectingStartDate,
                            startDate: startDate,
                            initialDate: isSelectingStartDate ? startDate : (endDate ?? Date()),
                            onStartDateSelected: { selectedDate in
                                startDate = selectedDate
                                showingPeriodSheet = false
                            },
                            onEndDateSelected: { selectedDate in
                                endDate = selectedDate
                                showingPeriodSheet = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            
            Spacer()
            
            // Bottom Buttons
            HStack(spacing: 12) {
                // Back Button
                Button(action: {
                    goBack()
                }) {
                    Image("Icon-leftArrow")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.onPrimaryContainer)
                        .frame(width: 48, height: 48)
                        .background(.primaryContainer)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Save Button
                Button(action: {
                    let newHabit = Habit(
                        name: step1Data.0,
                        description: step1Data.1,
                        icon: step1Data.2,
                        color: step1Data.3,
                        habitType: step1Data.4,
                        schedule: schedule,
                        goal: goal,
                        reminder: reminder,
                        startDate: startDate,
                        endDate: endDate
                    )
                    onSave(newHabit)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: UIScreen.main.bounds.width * 0.5)
                        .padding(.vertical, 16)
                        .background(step1Data.3)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(.surface2)
        .navigationBarHidden(true)
    }
}

#Preview {
    Text("Create Habit Step 2")
        .font(.title)
} 
