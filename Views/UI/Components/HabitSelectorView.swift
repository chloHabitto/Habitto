import SwiftUI

struct HabitSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedHabit: Habit?
    @EnvironmentObject var coreDataAdapter: CoreDataAdapter
    
    var body: some View {
        NavigationView {
            List {
                // All Habits Option
                Section {
                    Button(action: {
                        selectedHabit = nil
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("All Habits")
                                    .font(.appBodyMediumEmphasised)
                                    .foregroundColor(.onPrimaryContainer)
                                
                                Text("Overall progress and insights")
                                    .font(.appBodySmall)
                                    .foregroundColor(.text03)
                            }
                            
                            Spacer()
                            
                            if selectedHabit == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("Overview")
                        .font(.appBodySmallEmphasised)
                        .foregroundColor(.text02)
                        .textCase(.uppercase)
                }
                
                // Individual Habits
                if !coreDataAdapter.habits.isEmpty {
                    Section {
                        ForEach(coreDataAdapter.habits, id: \.id) { habit in
                            Button(action: {
                                selectedHabit = habit
                                dismiss()
                            }) {
                                HStack {
                                    Text(habit.icon ?? "📝")
                                        .font(.title2)
                                        .frame(width: 32)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(habit.name)
                                            .font(.appBodyMediumEmphasised)
                                            .foregroundColor(.onPrimaryContainer)
                                        
                                        Text(habit.goal)
                                            .font(.appBodySmall)
                                            .foregroundColor(.text03)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedHabit?.id == habit.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.primary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } header: {
                        Text("Individual Habits")
                            .font(.appBodySmallEmphasised)
                            .foregroundColor(.text02)
                            .textCase(.uppercase)
                    }
                } else {
                    Section {
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                    .foregroundColor(.text03)
                                
                                Text("No habits yet")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text03)
                                
                                Text("Create your first habit to see individual progress")
                                    .font(.appBodySmall)
                                    .foregroundColor(.text04)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Select Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HabitSelectorView(selectedHabit: .constant(nil))
        .environmentObject(CoreDataAdapter.shared)
}
