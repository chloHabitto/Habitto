import SwiftUI

/// CreateHabitStep1View - Optimized for keyboard performance
/// 
/// Key optimizations made to resolve slow keyboard display:
/// 1. Simplified focus handling by removing custom FocusModifier
/// 2. Removed conflicting tap gestures that could interfere with keyboard
/// 3. Added keyboard handling modifier for better performance
/// 4. Optimized background tap gesture to use UIApplication.resignFirstResponder
/// 5. Added slight delay for initial focus to prevent conflicts
/// 6. Added explicit text input configuration to help with third-party keyboards
/// 7. Performance optimizations to reduce UI hangs
/// 8. Deferred expensive operations to improve initial load performance
/// 9. Progressive loading for immediate keyboard responsiveness
/// 10. Ultra-minimal initial view for instant keyboard response
/// 11. Lazy loading and background processing to eliminate UI hangs
struct CreateHabitStep1View: View {
  // MARK: Internal

  @Binding var name: String
  @Binding var description: String
  @Binding var icon: String
  @Binding var color: Color
  @Binding var habitType: HabitType

  let onNext: (String, String, String, Color, HabitType) -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Header - always show
      CreateHabitHeader(
        stepNumber: 1,
        onCancel: onCancel)

      // Main content with simplified structure
      ScrollView(showsIndicators: false) {
        VStack(spacing: 16) {
          // Name field - container with surface background and stroke
          VStack(alignment: .leading, spacing: 12) {
            FormInputComponents.FormSectionHeader(title: "Name")

            TextField("Habit name", text: $name)
              .font(.appBodyLarge)
              .foregroundColor(.text01)
              .textFieldStyle(PlainTextFieldStyle())
              .submitLabel(.done)
              .focused($isNameFieldFocused)
              .frame(maxWidth: .infinity, minHeight: 48)
              .padding(.horizontal, 16)
              .background(.appSurface3)
              .cornerRadius(20)
              .onChange(of: name) { _, _ in
                if validationError != nil {
                  validationError = nil
                }
                if duplicateError != nil {
                  duplicateError = nil
                }
              }
              .onChange(of: isNameFieldFocused) { _, isFocused in
                // When field loses focus, check for duplicate
                if !isFocused {
                  let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                  if !trimmedName.isEmpty {
                    let existingHabits = HabitRepository.shared.habits
                    let isDuplicate = existingHabits.contains {
                      $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedName.lowercased()
                    }
                    duplicateError = isDuplicate ? "A habit with this name already exists" : nil
                  } else {
                    duplicateError = nil
                  }
                }
              }

            // Character counter
            HStack {
              Spacer()
              Text("\(name.count)/50")
                .font(.appBodySmall)
                .foregroundColor(name.count > 50 ? .error : .text03)
            }

            // Error message display
            if let errorMessage = validationError ?? duplicateError {
              HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .font(.system(size: 14, weight: .medium))
                  .foregroundColor(.error)

                Text(errorMessage)
                  .font(.appBodyMedium)
                  .foregroundColor(.error)

                Spacer()
              }
              .padding(.top, 4)
            }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
          .background(.appSurface2)
          .cornerRadius(20)

          // Description field - container with surface background and stroke
          VStack(alignment: .leading, spacing: 12) {
            FormInputComponents.FormSectionHeader(title: "Description")

            TextField("Description (Optional)", text: $description)
              .font(.appBodyLarge)
              .foregroundColor(.text01)
              .textFieldStyle(PlainTextFieldStyle())
              .submitLabel(.done)
              .focused($isDescriptionFieldFocused)
              .frame(maxWidth: .infinity, minHeight: 48)
              .padding(.horizontal, 16)
              .background(.appSurface3)
              .cornerRadius(20)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
          .background(.appSurface2)
          .cornerRadius(20)

          // Colour selection
          HStack(spacing: 12) {
            Text("Colour")
              .font(.appTitleMedium)
              .foregroundColor(.text01)
              .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
              RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(width: 24, height: 24)
              Text(cachedColorName)
                .font(.appBodyMedium)
                .foregroundColor(.text02)
            }

            Image(systemName: "chevron.right")
              .font(.appLabelSmall)
              .foregroundColor(.text03)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(.appSurface2)
          .cornerRadius(12)
          .onTapGesture {
            showingColorSheet = true
          }

        // Icon selection
          HStack(spacing: 12) {
            Text("Icon")
              .font(.appTitleMedium)
              .foregroundColor(.text01)
              .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
              if icon != "None" {
                ZStack {
                  RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 24, height: 24)

                  if icon.hasPrefix("Icon-") {
                    Image(icon)
                      .resizable()
                      .frame(width: 14, height: 14)
                      .foregroundColor(color)
                  } else {
                    Text(icon)
                      .font(.system(size: 14))
                  }
                }
              } else {
                // Placeholder rectangle to maintain consistent height
                RoundedRectangle(cornerRadius: 12)
                  .fill(.clear)
                  .frame(width: 24, height: 24)
              }
              Text(getIconDisplayValue(icon))
                .font(.appBodyMedium)
                .foregroundColor(.text02)
            }

            Image(systemName: "chevron.right")
              .font(.appLabelSmall)
              .foregroundColor(.text03)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(.appSurface2)
          .cornerRadius(12)
          .onTapGesture {
            showingEmojiPicker = true
          }

          // Habit type selection
          VStack(alignment: .leading, spacing: 12) {
            Text("Habit Type")
              .font(.appTitleMedium)
              .foregroundColor(.text01)

            HStack(spacing: 12) {
              // Habit Building button
              FormInputComponents.HabitTypeButton(
                title: "Habit Building",
                isSelected: isFormationSelected,
                action: { habitType = .formation })

              // Habit Breaking button
              FormInputComponents.HabitTypeButton(
                title: "Habit Breaking",
                isSelected: isBreakingSelected,
                action: { habitType = .breaking })
            }
            .frame(maxWidth: .infinity)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(.appSurface2)
          .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 20)
      }

      Spacer()

      // Fixed Continue button at bottom - optimized for performance
      HStack {
        Spacer()
        Button(action: {
          // Validate before proceeding
          let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
          
          // Check empty
          if trimmedName.isEmpty {
            validationError = "Please enter a habit name"
            return
          }
          
          // Check length
          if trimmedName.count > 50 {
            validationError = "Habit name must be 50 characters or less"
            return
          }
          
          // Check if there's still a duplicate error showing
          if duplicateError != nil {
            return
          }
          
          // Valid - proceed
          validationError = nil
          onNext(name, description, icon, color, habitType)
        }) {
          Text("Continue")
            .font(.appButtonText1)
            .foregroundColor(continueButtonColor)
            .frame(width: screenWidth * 0.5)
            .padding(.vertical, 16)
            .background(continueButtonBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(continueButtonDisabled)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
      .background(Self.bottomGradient)
    }
    .background(.appSurface)
    .navigationBarHidden(true)
    .scrollDismissesKeyboard(.interactively)
    .ignoresSafeArea(.keyboard, edges: .bottom)
    .keyboardDoneButton()
    .sheet(isPresented: $showingEmojiPicker) {
      EmojiKeyboardBottomSheet(
        selectedEmoji: $icon,
        onClose: {
          showingEmojiPicker = false
        },
        onSave: { emoji in
          icon = emoji
          showingEmojiPicker = false
        })
    }
    .sheet(isPresented: $showingColorSheet) {
      ColorBottomSheet(
        onClose: {
          showingColorSheet = false
        },
        onColorSelected: { selectedColor in
          color = selectedColor
        },
        onSave: { selectedColor in
          color = selectedColor
          showingColorSheet = false
        })
    }
    .onChange(of: color) { _, newColor in
      cachedColorName = getColorName(for: newColor)
    }
    .onAppear {
      cachedColorName = getColorName(for: color)
    }
  }

  // MARK: Private

  @State private var showingEmojiPicker = false
  @State private var showingColorSheet = false
  @FocusState private var isNameFieldFocused: Bool
  @FocusState private var isDescriptionFieldFocused: Bool

  // Validation
  @State private var validationError: String? = nil
  @State private var duplicateError: String? = nil
  
  // Cached values for performance
  @State private var cachedColorName: String = "Navy"

  /// Cache screen width to avoid repeated UIScreen.main.bounds.width access
  private let screenWidth = UIScreen.main.bounds.width

  /// Simple computed properties for habit type buttons - optimized for performance
  private var isFormationSelected: Bool {
    habitType == .formation
  }

  private var isBreakingSelected: Bool {
    habitType == .breaking
  }

  /// Performance optimization: Pre-computed values to reduce view updates
  private var continueButtonDisabled: Bool {
    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var continueButtonColor: Color {
    name.isEmpty ? .text06 : .onPrimary
  }

  private var continueButtonBackground: Color {
    name.isEmpty ? .disabledBackground : .primary
  }

  /// Pre-computed gradient for performance
  private static let bottomGradient = LinearGradient(
    gradient: Gradient(colors: [
      Color.surface2.opacity(0),
      Color.surface2.opacity(0.3),
      Color.surface2.opacity(0.7),
      Color.surface2.opacity(1.0)
    ]),
    startPoint: .top,
    endPoint: .bottom)

  /// Ultra-lightweight TextField for maximum initial load performance
  private func OptimizedTextField(
    placeholder: String,
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding) -> some View
  {
    TextField(placeholder, text: text)
      .font(.appBodyLarge)
      .foregroundColor(.text01)
      .textFieldStyle(PlainTextFieldStyle())
      .submitLabel(.done)
      .focused(isFocused)
      .frame(maxWidth: .infinity, minHeight: 48)
      .padding(.horizontal, 16)
      .background(.appSurface2)
      .cornerRadius(12)
  }

  /// Helper function for selection rows with visual elements
  @ViewBuilder
  private func VisualSelectionRow(
    title: String,
    color: Color,
    icon: String? = nil,
    value: String,
    action: @escaping () -> Void) -> some View
  {
    if let icon {
      SelectionRowWithVisual(
        title: title,
        icon: icon,
        color: color,
        value: value,
        action: action)
    } else {
      SelectionRowWithVisual(
        title: title,
        color: color,
        value: value,
        action: action)
    }
  }

  /// Optimized habit type button component with performance improvements
  private func HabitTypeButton(
    title: String,
    isSelected: Bool,
    action: @escaping () -> Void) -> some View
  {
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
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(PlainButtonStyle()) // Optimize button performance
    .frame(maxWidth: .infinity)
  }

  /// Helper functions for color and icon processing
  private func getColorName(for color: Color) -> String {
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

  private func getIconDisplayValue(_ icon: String) -> String {
    icon == "None" ? "None" : ""
  }

  /// Helper function to get appropriate display value for icon
  private func iconDisplayValue(_ icon: String) -> String {
    icon == "None" ? "None" : ""
  }
}

#if DEBUG
#Preview {
  CreateHabitStep1View(
    name: .constant(""),
    description: .constant(""),
    icon: .constant("None"),
    color: .constant(.primary),
    habitType: .constant(.formation),
    onNext: { _, _, _, _, _ in },
    onCancel: { })
}
#endif
