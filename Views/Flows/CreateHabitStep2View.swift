import SwiftUI

struct CreateHabitStep2View: View {
    let step1Data: (String, String, String, Color, HabitType)
    let habitToEdit: Habit?
    let goBack: () -> Void
    let onSave: (Habit) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var schedule: String = "Daily"
    @State private var goal: String = "1 time"
    @State private var reminder: String = "No reminder"
    @State private var startDate: Date = Date()
    @State private var endDate: Date? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: goBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("Step 2")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Color.clear.frame(width: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Schedule
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schedule")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        HStack {
                            Text(schedule)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Change") {
                                schedule = "Daily"
                            }
                        }
                        .modifier(InputFieldModifier())
                    }
                    
                    // Goal
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        HStack {
                            Text(goal)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Change") {
                                goal = "1 time"
                            }
                        }
                        .modifier(InputFieldModifier())
                    }
                    
                    // Reminder
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reminder")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        HStack {
                            Text(reminder)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Add") {
                                reminder = "9:00 AM"
                            }
                        }
                        .modifier(InputFieldModifier())
                    }
                    
                    // Period
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Period")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Date")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("Today")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button("Change") {
                                        startDate = Date()
                                    }
                                }
                                .modifier(InputFieldModifier())
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("End Date")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("Not Selected")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button("Set") {
                                        endDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days
                                    }
                                }
                                .modifier(InputFieldModifier())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(step1Data.3)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

#Preview {
    Text("Create Habit Step 2")
        .font(.title)
} 
