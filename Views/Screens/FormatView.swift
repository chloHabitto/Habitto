import SwiftUI

struct FormatView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var headerStyleSelection: String
    @Binding var habitListStyleSelection: String
    
    // Temporary state for changes before saving
    @State private var tempHeaderStyleSelection: String
    @State private var tempHabitListStyleSelection: String
    
    // Default selections
    init(headerStyleSelection: Binding<String>, habitListStyleSelection: Binding<String>) {
        self._headerStyleSelection = headerStyleSelection
        self._habitListStyleSelection = habitListStyleSelection
        // Initialize temporary state with current values
        self._tempHeaderStyleSelection = State(initialValue: headerStyleSelection.wrappedValue)
        self._tempHabitListStyleSelection = State(initialValue: habitListStyleSelection.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Format")
                        .font(.appTitleLargeEmphasised)
                        .foregroundColor(.primary)
                    
                    Text("Customize your home screen layout and appearance")
                        .font(.appBodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Header Style options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Header Style")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: tempHeaderStyleSelection == "Tabs" ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                            Text("Tabs")
                                .font(.appBodyMedium)
                                .foregroundColor(.primary)
                        }
                        .onTapGesture {
                            tempHeaderStyleSelection = "Tabs"
                        }
                        
                        HStack {
                            Image(systemName: tempHeaderStyleSelection == "Today's Progress card" ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                            Text("Today's Progress card (in Progress tab)")
                                .font(.appBodyMedium)
                                .foregroundColor(.primary)
                        }
                        .onTapGesture {
                            tempHeaderStyleSelection = "Today's Progress card"
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .padding(.vertical, 16)
                .background(Color.red)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Habit list structure options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Habit List Style")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: tempHabitListStyleSelection == "List view" ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                            Text("List view")
                                .font(.appBodyMedium)
                                .foregroundColor(.primary)
                        }
                        .onTapGesture {
                            tempHabitListStyleSelection = "List view"
                        }
                        
                        HStack {
                            Image(systemName: tempHabitListStyleSelection == "Card View" ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                            Text("Card View")
                                .font(.appBodyMedium)
                                .foregroundColor(.primary)
                        }
                        .onTapGesture {
                            tempHabitListStyleSelection = "Card View"
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .padding(.vertical, 16)
                .background(Color.red)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Save button
                Button(action: {
                    // Apply the temporary changes to the actual bindings
                    print("💾 Before save - headerStyleSelection: \(headerStyleSelection)")
                    print("💾 Before save - tempHeaderStyleSelection: \(tempHeaderStyleSelection)")
                    
                    headerStyleSelection = tempHeaderStyleSelection
                    habitListStyleSelection = tempHabitListStyleSelection
                    
                    print("💾 After save - headerStyleSelection: \(headerStyleSelection)")
                    print("💾 Save button tapped - Applied changes")
                    
                    // Force a UI update
                    DispatchQueue.main.async {
                        print("💾 Forcing UI update on main queue")
                    }
                    
                    dismiss()
                }) {
                    Text("Save")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.appBodyMedium)
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview {
    FormatView(
        headerStyleSelection: .constant("Tabs"),
        habitListStyleSelection: .constant("List view")
    )
}
