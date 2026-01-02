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
    let _ = print("⌨️ STEP1: body evaluated at \(Date())")
    VStack(spacing: 0) {
      // Header - always show
      CreateHabitHeader(
        stepNumber: 1,
        onCancel: onCancel)

      // Main content with simplified structure
      ScrollView(showsIndicators: false) {
        VStack(spacing: 12) {
          // Name field - container with surface background and stroke
          VStack(alignment: .leading, spacing: 12) {
            FormInputComponents.FormSectionHeader(title: "Name")
            
            LimitedTextField(
              placeholder: "Habit name",
              text: $name,
              isFocused: $isNameFieldFocused,
              maxLength: 50,
              limitReached: $nameLimitReached
            )
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
            
            // Keep error message for duplicate habit names (shown on focus loss)
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
            }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
          .background(.appSurface01Variant)
          .cornerRadius(20)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)

          // Description field - container with surface background and stroke
          VStack(alignment: .leading, spacing: 12) {
            FormInputComponents.FormSectionHeader(title: "Description")
            
            LimitedTextField(
              placeholder: "Description (Optional)",
              text: $description,
              isFocused: $isDescriptionFieldFocused,
              maxLength: 50,
              limitReached: $descriptionLimitReached
            )
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
          .background(.appSurface01Variant)
          .cornerRadius(20)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)

          // Colour selection
          HStack(spacing: 12) {
            Text("Colour")
              .font(.appTitleMedium)
              .foregroundColor(.text02)
              .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
              RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(width: 24, height: 24)
              Text(cachedColorName)
                .font(.appBodyMedium)
                .foregroundColor(.appText04)
            }

            Image(systemName: "chevron.right")
              .font(.appLabelSmall)
              .foregroundColor(.text03)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(.appSurface01Variant)
          .cornerRadius(16)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)
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
                .foregroundColor(.appText04)
            }

            Image(systemName: "chevron.right")
              .font(.appLabelSmall)
              .foregroundColor(.text03)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(.appSurface01Variant)
          .cornerRadius(16)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)
          .onTapGesture {
            showingEmojiPicker = true
          }

          // Habit type selection
          VStack(alignment: .leading, spacing: 12) {
            Text("Habit Type")
              .font(.appTitleMedium)
              .foregroundColor(.text02)

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
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
          .background(.appSurface01Variant)
          .cornerRadius(20)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
          .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)
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
          let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
          
          // Check empty
          if trimmedName.isEmpty {
            validationError = "Please enter a habit name"
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
      .background(.appSurface04Variant)
    }
    .background(.appSurface04Variant)
    .navigationBarHidden(true)
    .scrollDismissesKeyboard(.interactively)
    .ignoresSafeArea(.keyboard, edges: .bottom)
    // .keyboardDoneButton()  // TEMP: Testing keyboard lag
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
        },
        initialColor: color)
    }
    .onChange(of: color) { _, newColor in
      cachedColorName = getColorName(for: newColor)
    }
    .onAppear {
      print("⌨️ STEP1: onAppear START at \(Date())")
      cachedColorName = getColorName(for: color)
      print("⌨️ STEP1: onAppear END at \(Date())")
      
      // Check if main thread is responsive
      DispatchQueue.main.async {
        print("⌨️ STEP1: Main thread responsive at \(Date())")
      }
      
      // Auto-focus name field after sheet animation (keyboard loads during this natural pause)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        isNameFieldFocused = true
      }
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
  
  // Character limit tracking
  @State private var nameLimitReached: Bool = false
  @State private var descriptionLimitReached: Bool = false
  
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

  /// TextField with character limit and inline feedback
  @ViewBuilder
  private func LimitedTextField(
    placeholder: String,
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding,
    maxLength: Int,
    limitReached: Binding<Bool>
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ZStack(alignment: .leading) {
        // Placeholder text
        if text.wrappedValue.isEmpty {
          Text(placeholder)
            .font(.appBodyLarge)
            .foregroundColor(.text05)
        }
        // Actual text field
        TextField("", text: text)
          .font(.appBodyLarge)
          .foregroundColor(.text01)
          .textFieldStyle(PlainTextFieldStyle())
          .submitLabel(.done)
          .focused(isFocused)
          .onAppear {
            print("⌨️ TEXTFIELD: onAppear at \(Date())")
          }
          .onChange(of: isFocused.wrappedValue) { oldValue, newValue in
            print("⌨️ TEXTFIELD: focus changed \(oldValue) → \(newValue) at \(Date())")
          }
      }
      .frame(maxWidth: .infinity, minHeight: 48)
      .padding(.horizontal, 16)
      .background(.appSurface01Variant)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(limitReached.wrappedValue && isFocused.wrappedValue ? .warning : .outline3, lineWidth: 1.5))
      .cornerRadius(12)
        .onChange(of: text.wrappedValue) { oldValue, newValue in
          // Enforce character limit
          if newValue.count > maxLength {
            text.wrappedValue = String(newValue.prefix(maxLength))
          }
          // Update limit reached state
          limitReached.wrappedValue = text.wrappedValue.count >= maxLength
        }
      
      // Counter and message - only show when focused
      if isFocused.wrappedValue {
        HStack {
          // Limit reached message
          if limitReached.wrappedValue {
            Text("Maximum \(maxLength) characters reached")
              .font(.appBodySmall)
              .foregroundColor(.warning)
          }
          
          Spacer()
          
          // Character counter
          Text("\(text.wrappedValue.count)/\(maxLength)")
            .font(.appBodySmall)
            .foregroundColor(limitReached.wrappedValue ? .warning : .text03)
        }
      }
    }
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
      (Color("pastelYellow"), "Yellow"),
      (Color("pastelBlue"), "Blue"),
      (Color("pastelPurple"), "Purple")
    ]

    // Find the matching color and return its name
    for (colorOption, name) in colors {
      if color == colorOption {
        return name
      }
    }

    return "Blue" // Default fallback to pastelBlue
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
