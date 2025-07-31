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
    @FocusState private var isNameFieldFocused: Bool
    
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
                    .font(.appTitleMedium)
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
                        .font(.appHeadlineMediumEmphasised)
                        .foregroundColor(.text01)
                    Text("Let's get started!")
                        .font(.appTitleMedium)
                        .foregroundColor(.text04)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Name field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            TextField("Enter habit name", text: $name)
                                .font(.appBodyLarge)
                                .foregroundColor(.text01)
                                .accentColor(.primary)
                                .focused($isNameFieldFocused)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isNameFieldFocused ? .primary : .outline, lineWidth: 1.5)
                                )
                                .cornerRadius(12)
                                .frame(minHeight: 48)
                                .submitLabel(.done)
                                .onTapGesture {
                                    isNameFieldFocused = true
                                }
                                .scaleEffect(isNameFieldFocused ? 1.02 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isNameFieldFocused)
                        }
                        
                        // Description field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            MultilineTextField(text: $description, placeholder: "Enter description (optional)")
                                .frame(minHeight: 48, maxHeight: 120)
                        }
                        
                        // Icon selection
                        Button(action: {
                            showingIconSheet = true
                        }) {
                            HStack {
                                Text("Icon")
                                    .font(.appTitleMedium)
                                    .foregroundColor(.text01)
                                Spacer()
                                Text(icon == "None" ? "None" : icon)
                                    .font(.appBodyLarge)
                                    .foregroundColor(.text04)
                                Image(systemName: "chevron.right")
                                    .font(.appLabelSmall)
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
                                    .font(.appTitleMedium)
                                    .foregroundColor(.text01)
                                Spacer()
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 16, height: 16)
                                    Text(colorName(for: color))
                                        .font(.appBodyLarge)
                                        .foregroundColor(.text04)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.appLabelMedium)
                                    .foregroundColor(.primaryDim)
                            }
                        }
                        .selectionRowStyle()
                        
                        // Habit type selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Habit Type")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            HStack(spacing: 12) {
                                // Habit Formation button
                                Button(action: {
                                    habitType = .formation
                                }) {
                                    HStack(spacing: 8) {
                                        if habitType == .formation {
                                            Image(systemName: "checkmark")
                                                .font(.appLabelSmallEmphasised)
                                                .foregroundColor(.onPrimary)
                                        }
                                        Text("Habit Formation")
                                            .font(habitType == .formation ? .appLabelLargeEmphasised : .appLabelLarge)
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
                                                .font(.appLabelSmallEmphasised)
                                                .foregroundColor(.onPrimary)
                                        }
                                        Text("Habit Breaking")
                                            .font(habitType == .breaking ? .appLabelLargeEmphasised : .appLabelLarge)
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
                            .font(.appButtonText1)
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
            
            // Auto-focus the name field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFieldFocused = true
            }
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
        .font(.appTitleMedium)
}

// Custom MultilineTextField to handle Done button properly
struct MultilineTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MultilineTextField

        init(_ parent: MultilineTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            print("Done button pressed - dismissing keyboard")
            textField.resignFirstResponder()
            return true
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            if textField.text == parent.placeholder {
                textField.text = ""
                textField.textColor = UIColor(Color(hex: "1C274C"))
            }
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            if textField.text?.isEmpty == true {
                textField.text = parent.placeholder
                textField.textColor = UIColor.placeholderText
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.backgroundColor = UIColor.clear
        textField.returnKeyType = .done
        textField.text = placeholder
        textField.textColor = UIColor.placeholderText
        textField.placeholder = placeholder
        
        // Apply styling to match the app's design
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1.5
        textField.layer.borderColor = UIColor(Color.outline).cgColor
        textField.backgroundColor = UIColor(Color.surface)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: textField.frame.height))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: textField.frame.height))
        textField.rightViewMode = .always
        
        // Improve tap responsiveness
        textField.isUserInteractionEnabled = true
        textField.isMultipleTouchEnabled = false
        
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text && !text.isEmpty {
            uiView.text = text
            uiView.textColor = UIColor(Color(hex: "1C274C"))
        }
        uiView.returnKeyType = .done
    }
} 
