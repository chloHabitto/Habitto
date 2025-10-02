import SwiftUI

struct TestHabitEdit: View {
    @State private var showingEditView = false
    
    let testHabit = Habit(
        name: "Test Habit",
        description: "Test description",
        icon: "📝",
        color: .blue,
        habitType: .formation,
        schedule: "Daily",
        goal: "1 time",
        reminder: "No reminder",
        startDate: Date(),
        endDate: nil,
        isCompleted: false,
        streak: 0
    )
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test Habit Edit View")
                .font(.title)
            
            Button("Open HabitEditView") {
                print("🔄 TestHabitEdit: Button tapped")
                showingEditView = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .fullScreenCover(isPresented: $showingEditView) {
            HabitEditView(habit: testHabit, onSave: { updatedHabit in
                print("🔄 TestHabitEdit: HabitEditView save called")
                print("🔄 TestHabitEdit: Updated habit name: \(updatedHabit.name)")
                showingEditView = false
            })
        }
    }
}

#Preview {
    TestHabitEdit()
} 