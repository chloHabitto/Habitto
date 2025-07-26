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
    @State private var showingScheduleSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Cancel button (same as Step 1)
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .font(.buttonText2)
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
                    .font(.headlineMediumEmphasised)
                    .foregroundColor(.text01)
                Text("Let's get started!")
                    .font(.titleSmall)
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
                                .font(.titleMedium)
                                .foregroundColor(.text01)
                            Spacer()
                            Text(schedule)
                                .font(.bodyLarge)
                                .foregroundColor(.text04)
                            Image(systemName: "chevron.right")
                                .font(.labelMedium)
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
                    HStack {
                        Text("Goal")
                            .font(.titleMedium)
                            .foregroundColor(.text01)
                        Spacer()
                        Text("1 time")
                            .font(.bodyLarge)
                            .foregroundColor(.text04)
                        Image(systemName: "chevron.right")
                            .font(.labelMedium)
                            .foregroundColor(.primaryDim)
                    }
                    .selectionRowStyle()
                    
                    // Reminder
                    HStack {
                        Text("Reminder")
                            .font(.titleMedium)
                            .foregroundColor(.text01)
                        Spacer()
                        Text("Add")
                            .font(.bodyLarge)
                            .foregroundColor(.text04)
                        Image(systemName: "chevron.right")
                            .font(.labelMedium)
                            .foregroundColor(.primaryDim)
                    }
                    .selectionRowStyle()
                    
                    // Period
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Period")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Date")
                                    .font(.bodyMedium)
                                    .foregroundColor(.text05)
                                Text("Today")
                                    .font(.bodyLarge)
                                    .foregroundColor(.text04)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                .inputFieldStyle()
                            }
                            .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("End Date")
                                    .font(.bodyMedium)
                                    .foregroundColor(.text05)
                                Text("Not Selected")
                                    .font(.bodyLarge)
                                    .foregroundColor(.text04)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                .inputFieldStyle()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .selectionRowStyle()
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
                        .font(.system(size: 18, weight: .semibold))
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
