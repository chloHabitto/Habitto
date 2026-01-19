import SwiftUI

// MARK: - SkipHabitSheet

struct SkipHabitSheet: View {
  // MARK: Internal
  
  let habitName: String
  let habitColor: Color
  let onSkip: (SkipReason) -> Void
  
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    BaseBottomSheet(
      title: "Skip \"\(habitName)\"",
      description: "Your streak will stay protected",
      onClose: { dismiss() },
      useSimpleCloseButton: true
    ) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Why are you skipping?")
          .font(.appBodyMediumEmphasised)
          .foregroundColor(.text03)
          .padding(.horizontal, 20)
          .padding(.top, 16)
        
        // Reason Grid
        LazyVGrid(columns: [
          GridItem(.flexible()),
          GridItem(.flexible()),
          GridItem(.flexible()),
          GridItem(.flexible())
        ], spacing: 12) {
          ForEach(SkipReason.allCases, id: \.self) { reason in
            SkipReasonChip(reason: reason) {
              handleSkip(reason)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        
        Spacer()
      }
    }
    .presentationDetents([.height(400)])
  }
  
  // MARK: Private
  
  private func handleSkip(_ reason: SkipReason) {
    // Haptic feedback
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    
    // Call the skip handler
    onSkip(reason)
    
    // Dismiss the sheet
    dismiss()
  }
}

// MARK: - SkipReasonChip

struct SkipReasonChip: View {
  let reason: SkipReason
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: reason.icon)
          .font(.system(size: 20))
          .foregroundColor(.text01)
        
        Text(reason.shortLabel)
          .font(.appLabelSmall)
          .foregroundColor(.text01)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.surfaceContainer)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.outline3.opacity(0.3), lineWidth: 1)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// MARK: - Preview

#Preview {
  SkipHabitSheet(
    habitName: "Morning Run",
    habitColor: .blue,
    onSkip: { reason in
      print("Skipped with reason: \(reason.rawValue)")
    }
  )
  .background(Color.black.opacity(0.3))
}
