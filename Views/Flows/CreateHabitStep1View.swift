import SwiftUI

struct CreateHabitStep1View: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var icon: String
    @Binding var color: Color
    @Binding var habitType: HabitType
    let onNext: (String, String, String, Color, HabitType) -> Void
    let onCancel: () -> Void
    
    static let colorOptions: [(Color, String)] = [
        (Color(red: 0.11, green: 0.15, blue: 0.30), "Navy"),
        (Color(red: 0.91, green: 0.30, blue: 0.30), "Red"),
        (Color(red: 0.30, green: 0.91, blue: 0.30), "Green"),
        (Color(red: 0.91, green: 0.91, blue: 0.30), "Yellow"),
        (Color(red: 0.91, green: 0.30, blue: 0.91), "Purple"),
        (Color(red: 0.30, green: 0.91, blue: 0.91), "Cyan"),
        (Color(red: 0.91, green: 0.60, blue: 0.30), "Orange"),
        (Color(red: 0.60, green: 0.30, blue: 0.91), "Violet")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Cancel button
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .font(.buttonText2)
                .foregroundColor(Color(red: 0.15, green: 0.23, blue: 0.42))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Progress indicator
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.primaryDim)
                    .frame(width: 32, height: 8)
                Rectangle()
                    .fill(.surfaceContainer)
                    .frame(width: 32, height: 8)
            }
            .frame(width: 64, height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Header
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
                    // Name field
                    TextField("Name", text: $name)
                        .font(.bodyLarge)
                        .foregroundColor(.text01)
                        .accentColor(.text01)
                        .modifier(InputFieldModifier())
                    
                    // Description field
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.bodyLarge)
                        .foregroundColor(.text01)
                        .accentColor(.text01)
                        .modifier(InputFieldModifier())
                    
                    // Icon selection
                    HStack {
                        Text("Icon")
                            .font(.titleMedium)
                            .foregroundColor(.text01)
                        Spacer()
                        Text(icon == "None" ? "None" : icon)
                            .font(.bodyLarge)
                            .foregroundColor(.text04)
                        Image(systemName: "chevron.right")
                            .font(.labelMedium)
                            .foregroundColor(.primaryDim)
                    }
                    .modifier(SelectionRowModifier())
                    
                    // Color selection
                    HStack {
                        Text("Colour")
                            .font(.titleMedium)
                            .foregroundColor(.text01)
                        Spacer()
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color)
                                .frame(width: 16, height: 16)
                            Text(colorName(for: color))
                                .font(.bodyLarge)
                                .foregroundColor(.text04)
                        }
                        Image(systemName: "chevron.right")
                            .font(.labelMedium)
                            .foregroundColor(.primaryDim)
                    }
                    .modifier(SelectionRowModifier())
                    
                    // Habit type selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Habit Type")
                            .font(.titleMedium)
                            .foregroundColor(.text01)
                        
                        HStack(spacing: 12) {
                            // Habit Formation button
                            Button(action: {
                                habitType = .formation
                            }) {
                                HStack(spacing: 8) {
                                    if habitType == .formation {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.onPrimary)
                                    }
                                    Text("Habit Formation")
                                        .font(habitType == .formation ? .labelLargeEmphasised : .labelLarge)
                                        .foregroundColor(habitType == .formation ? .onPrimary : .onPrimaryContainer)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                                                .background(habitType == .formation ? .primary : .primaryContainer)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.outline, lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Habit Breaking button
                            Button(action: {
                                habitType = .breaking
                            }) {
                                HStack(spacing: 8) {
                                    if habitType == .breaking {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.onPrimary)
                                    }
                                    Text("Habit Breaking")
                                        .font(habitType == .breaking ? .labelLargeEmphasised : .labelLarge)
                                        .foregroundColor(habitType == .breaking ? .onPrimary : .onPrimaryContainer)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(habitType == .breaking ? .primary : .primaryContainer)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.outline, lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.outline, lineWidth: 1.5)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            
            Spacer()
            
            // Continue button
            HStack {
                Spacer()
                Button(action: {
                    onNext(name, description, icon, color, habitType)
                }) {
                    Text("Continue")
                        .font(.buttonText1)
                        .foregroundColor(name.isEmpty ? .text06 : .onPrimary)
                        .frame(width: UIScreen.main.bounds.width * 0.5)
                        .padding(.vertical, 16)
                        .background(name.isEmpty ? .disabledBackground : .primary)
                        .clipShape(Capsule())
                }
                .disabled(name.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(.surface2)
        .navigationBarHidden(true)
    }
    
    private func colorName(for color: Color) -> String {
        for (optionColor, name) in Self.colorOptions {
            if color == optionColor {
                return name
            }
        }
        return "Navy"
    }
}

#Preview {
    Text("Create Habit Step 1")
        .font(.title)
} 