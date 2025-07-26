import SwiftUI

struct CreateHabitStep1View: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var icon: String
    @Binding var color: Color
    @Binding var habitType: HabitType
    let onNext: (String, String, String, Color, HabitType) -> Void
    let onCancel: () -> Void
    
    @State private var showingIconSheet = false
    @State private var showingColorSheet = false
    
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
        ZStack(alignment: .bottom) {
            // Main content
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
                            .inputFieldStyle()
                            .contentShape(Rectangle())
                            .frame(minHeight: 48)
                            .submitLabel(.done)
                        
                        // Description field
                        TextField("Description (Optional)", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.bodyLarge)
                            .foregroundColor(.text01)
                            .accentColor(.text01)
                            .inputFieldStyle()
                            .contentShape(Rectangle())
                            .frame(minHeight: 48)
                            .submitLabel(.done)
                        
                        // Icon selection
                        Button(action: {
                            showingIconSheet = true
                        }) {
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
                        }
                        .selectionRowStyle()
                        
                        // Color selection
                        Button(action: {
                            showingColorSheet = true
                        }) {
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
                        }
                        .selectionRowStyle()
                        
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
                    .padding(.bottom, 100) // Add padding to account for fixed button
                }
            }
            .background(.surface2)
            
            // Fixed Continue button at bottom
            VStack {
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
                .background(.surface2)
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            // Customize keyboard return button appearance globally
            UITextField.appearance().tintColor = UIColor(Color(hex: "1C274C"))
            UITextField.appearance().keyboardAppearance = .light
        }
        .sheet(isPresented: $showingIconSheet) {
            IconBottomSheet(
                selectedIcon: $icon,
                onClose: { showingIconSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingColorSheet) {
            ColorBottomSheet(
                onClose: { showingColorSheet = false },
                onColorSelected: { selectedColor in
                    color = selectedColor
                    showingColorSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func colorName(for color: Color) -> String {
        // Match the colors from ColorBottomSheet
        let colorOptions: [(Color, String)] = [
            (Color(hex: "222222"), "Black"),
            (.primary, "Navy"),
            (Color(hex: "6096FD"), "Blue"),
            (Color(hex: "CB30E0"), "Purple"),
            (Color(hex: "FF2D55"), "Red"),
            (Color(hex: "FF7838"), "Orange"),
            (Color(hex: "34C759"), "Green"),
            (Color(hex: "21EAF1"), "Teal")
        ]
        
        for (optionColor, name) in colorOptions {
            if color == optionColor {
                return name
            }
        }
        return "Navy" // Default fallback
    }
}

#Preview {
    Text("Create Habit Step 1")
        .font(.title)
} 