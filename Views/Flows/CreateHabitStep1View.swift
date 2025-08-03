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
            .foregroundColor(.text01)
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
    
    // Helper function for selection rows with visual elements
    @ViewBuilder
    private func VisualSelectionRow(
        title: String,
        color: Color,
        icon: String? = nil,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        if let icon = icon {
            SelectionRowWithVisual(
                title: title,
                icon: icon,
                color: color,
                value: value,
                action: action
            )
        } else {
            SelectionRowWithVisual(
                title: title,
                color: color,
                value: value,
                action: action
            )
        }
    }
    
    // Helper function to get appropriate display value for icon
    private func iconDisplayValue(_ icon: String) -> String {
        return icon == "None" ? "None" : ""
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
        VStack(spacing: 0) {
            // Header
            CreateHabitHeader(
                stepNumber: 1,
                onCancel: onCancel
            )
            
            // Main content with ScrollView
            ScrollView {
                VStack(spacing: 16) {
                    // Name field - moved inside ScrollView for better keyboard handling
                    CustomTextField(placeholder: "Name", text: $name, isFocused: $isNameFieldFocused, showTapGesture: true)
                        .zIndex(1)
                    
                    // Description field
                    CustomTextField(placeholder: "Description (Optional)", text: $description, isFocused: $isDescriptionFieldFocused, showTapGesture: true)
                        .zIndex(1)
                    
                    // Color and Icon selection
                    Group {
                        VisualSelectionRow(
                            title: "Colour",
                            color: color,
                            value: colorName(for: color),
                            action: { showingColorSheet = true }
                        )
                        
                        VisualSelectionRow(
                            title: "Icon",
                            color: color,
                            icon: icon,
                            value: iconDisplayValue(icon),
                            action: { showingIconSheet = true }
                        )
                    }
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
                .padding(.top, 0)
                .padding(.bottom, 20) // Reduced padding since we're using Spacer
            }
            .onTapGesture {
                // Fix for gesture recognition issues with ScrollView
            }
            
            Spacer() // This pushes the button to the bottom
            
            // Fixed Continue button at bottom
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
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.surface2.opacity(0),
                        Color.surface2.opacity(0.3),
                        Color.surface2.opacity(0.7),
                        Color.surface2.opacity(1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(.surface2)
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
        // Use the same color definitions as ColorBottomSheet for consistency
        let colors: [(color: Color, name: String)] = [
            (Color(hex: "222222"), "Black"),
            (.primary, "Navy"),
            (Color(hex: "6096FD"), "Blue"),
            (Color(hex: "CB30E0"), "Purple"),
            (Color(hex: "FF2D55"), "Red"),
            (Color(hex: "FF7838"), "Orange"),
            (Color(hex: "34C759"), "Green"),
            (Color(hex: "21EAF1"), "Teal")
        ]
        
        // Find the matching color and return its name
        for (colorOption, name) in colors {
            if color == colorOption {
                return name
            }
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


