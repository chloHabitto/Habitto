import SwiftUI

struct CreateHabitStep1View: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var icon: String
    @Binding var color: Color
    @Binding var habitType: HabitType
    @Binding var isInitialLoad: Bool
    let onNext: (String, String, String, Color, HabitType) -> Void
    let onCancel: () -> Void
    
    @State private var showingIconSheet = false
    @State private var showingColorSheet = false
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isDescriptionFieldFocused: Bool
    
    // Cache screen width to avoid repeated UIScreen.main.bounds.width access
    private let screenWidth = UIScreen.main.bounds.width
    
    // Computed properties to optimize habit type button styling
    private var isFormationSelected: Bool {
        habitType == .formation
    }
    
    private var isBreakingSelected: Bool {
        habitType == .breaking
    }
    
    // Custom reusable TextField component
    private func CustomTextField(
        placeholder: String,
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding? = nil,
        showTapGesture: Bool = false
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.appBodyLarge)
            .foregroundColor(.text05)
            .textFieldStyle(PlainTextFieldStyle())
            .submitLabel(.done)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .background(.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.outline, lineWidth: 1.5)
            )
            .cornerRadius(12)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .modifier(FocusModifier(isFocused: isFocused, showTapGesture: showTapGesture))
    }
    
    // Custom modifier to handle focus and tap gesture
    private struct FocusModifier: ViewModifier {
        let isFocused: FocusState<Bool>.Binding?
        let showTapGesture: Bool
        
        func body(content: Content) -> some View {
            if let isFocused = isFocused {
                content
                    .focused(isFocused)
                    .onTapGesture {
                        isFocused.wrappedValue = true
                    }
            } else {
                content
                    .onTapGesture {
                        // For fields without focus binding, just ensure they can be tapped
                        // SwiftUI will handle focus automatically
                    }
            }
        }
    }
    
    // Custom reusable habit type button component
    private func HabitTypeButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.appLabelSmallEmphasised)
                        .foregroundColor(.onPrimary)
                }
                Text(title)
                    .font(isSelected ? .appLabelLargeEmphasised : .appLabelLarge)
                    .foregroundColor(isSelected ? .onPrimary : .onPrimaryContainer)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? .primary : .primaryContainer)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.outline, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            VStack(spacing: 0) {
                // Header
                CreateHabitHeader(
                    stepNumber: 1,
                    onCancel: onCancel
                )
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Name field - moved inside ScrollView for better keyboard handling
                        CustomTextField(placeholder: "Name", text: $name, isFocused: $isNameFieldFocused, showTapGesture: true)
                            .zIndex(1)
                        
                        // Description field
                        CustomTextField(placeholder: "Description (Optional)", text: $description, isFocused: $isDescriptionFieldFocused, showTapGesture: true)
                            .zIndex(1)
                        
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
                        .zIndex(1)
                        
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
                        .zIndex(1)
                        
                        // Habit type selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Habit Type")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            HStack(spacing: 12) {
                                // Habit Building button
                                HabitTypeButton(title: "Habit Building", isSelected: isFormationSelected) {
                                    habitType = .formation
                                }
                                
                                // Habit Breaking button
                                HabitTypeButton(title: "Habit Breaking", isSelected: isBreakingSelected) {
                                    habitType = .breaking
                                }
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
                        .zIndex(1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
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
                            .frame(width: screenWidth * 0.5)
                            .padding(.vertical, 16)
                            .background(name.isEmpty ? .disabledBackground : .primary)
                            .clipShape(Capsule())
                    }
                    .disabled(name.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(.surface2)
                .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .background(
            Color.surface2
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss keyboard when tapping background
                    isNameFieldFocused = false
                    isDescriptionFieldFocused = false
                }
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            // Auto-focus the name field only on initial load
            if isInitialLoad {
                isNameFieldFocused = true
                isInitialLoad = false
            }
        }
        .sheet(isPresented: $showingIconSheet) {
            IconBottomSheet(
                selectedIcon: $icon,
                onClose: { showingIconSheet = false }
            )
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
}

private func colorName(for color: Color) -> String {
        // Use cached color comparisons to avoid expensive Color(hex:) initializations
        // These colors should match the ones from ColorBottomSheet
        if color == Color(red: 0.13, green: 0.13, blue: 0.13) { // #222222
            return "Black"
        } else if color == .primary {
            return "Navy"
        } else if color == Color(red: 0.38, green: 0.59, blue: 0.99) { // #6096FD
            return "Blue"
        } else if color == Color(red: 0.80, green: 0.18, blue: 0.88) { // #CB30E0
            return "Purple"
        } else if color == Color(red: 1.0, green: 0.18, blue: 0.33) { // #FF2D55
            return "Red"
        } else if color == Color(red: 1.0, green: 0.47, blue: 0.22) { // #FF7838
            return "Orange"
        } else if color == Color(red: 0.20, green: 0.78, blue: 0.35) { // #34C759
            return "Green"
        } else if color == Color(red: 0.13, green: 0.92, blue: 0.95) { // #21EAF1
            return "Teal"
        }
        return "Navy" // Default fallback
    }

#Preview {
    CreateHabitStep1View(
        name: .constant(""),
        description: .constant(""),
        icon: .constant("None"),
        color: .constant(.primary),
        habitType: .constant(.formation),
        isInitialLoad: .constant(true),
        onNext: { _, _, _, _, _ in },
        onCancel: {}
    )
}


