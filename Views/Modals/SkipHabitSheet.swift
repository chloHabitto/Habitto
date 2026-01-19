import SwiftUI

// MARK: - SkipHabitSheet

struct SkipHabitSheet: View {
  // MARK: Internal
  
  let habitName: String
  let habitColor: Color
  let initialSelectedReason: SkipReason? // NEW - optional pre-selected reason
  let onSkip: (SkipReason) -> Void
  
  @Environment(\.dismiss) private var dismiss
  @State private var selectedReason: SkipReason?
  
  var body: some View {
    VStack(spacing: 20) {
      // Header Section
      headerSection
      
      // Reason Selection Section
      reasonSelectionSection
      
      // Action Buttons
      Spacer()
      
      actionButtons
    }
    .padding(.horizontal, 24)
    .padding(.top, 8)
    .padding(.bottom, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.appSurface01Variant)
    .ignoresSafeArea(edges: .bottom)
    .presentationDetents([.height(540)])
    .onAppear {
      // Pre-select the reason if provided
      if selectedReason == nil, let initial = initialSelectedReason {
        selectedReason = initial
      }
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    VStack(spacing: 4) {
      // Close button
      HStack {
        Spacer()
        
        Button(action: {
          dismiss()
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(.text07)
            .frame(width: 44, height: 44)
        }
        .padding(.trailing, -12)
      }
      .padding(.top, 8)
      
      // Title
      Text("Skip \"\(habitName)\"")
        .font(Font.appHeadlineSmallEmphasised)
        .foregroundColor(.text01)
        .frame(maxWidth: .infinity, alignment: .center)
      
      // Description
      Text("Your streak will stay protected")
        .font(Font.appBodyMediumEmphasised)
        .foregroundColor(.text05)
        .frame(maxWidth: .infinity, alignment: .center)
    }
  }
  
  // MARK: - Reason Selection Section
  
  private var reasonSelectionSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Why are you skipping?")
        .font(.appBodyMediumEmphasised)
        .foregroundColor(.text03)
        .frame(maxWidth: .infinity, alignment: .leading)
      
      // Reason Grid
      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 12) {
        ForEach(SkipReason.allCases, id: \.self) { reason in
          SkipReasonChip(
            reason: reason,
            isSelected: selectedReason == reason
          ) {
            selectedReason = reason
          }
        }
      }
    }
  }
  
  // MARK: - Action Buttons
  
  private var actionButtons: some View {
    HStack(spacing: 16) {
      // Cancel button
      Button(action: {
        dismiss()
      }) {
        Text("Cancel")
          .font(Font.appButtonText1)
          .foregroundColor(.text04)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(.badgeBackground)
          .cornerRadius(30)
      }
      .buttonStyle(PlainButtonStyle())
      
      // Save button
      Button(action: {
        if let reason = selectedReason {
          handleSkip(reason)
        }
      }) {
        Text("Skip")
          .font(Font.appButtonText1)
          .foregroundColor(.onPrimary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(selectedReason != nil ? .primary : .disabledBackground)
          .cornerRadius(30)
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(selectedReason == nil)
    }
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
  let isSelected: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: reason.icon)
          .font(.system(size: 20))
          .foregroundColor(isSelected ? .primary : .text01)
        
        Text(reason.shortLabel)
          .font(.appLabelSmall)
          .foregroundColor(isSelected ? .primary : .text01)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.primary.opacity(0.1) : Color.surfaceContainer)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.primary : Color.outline3.opacity(0.3), lineWidth: isSelected ? 2 : 1)
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
    initialSelectedReason: nil, // NEW parameter
    onSkip: { reason in
      print("Skipped with reason: \(reason.rawValue)")
    }
  )
  .presentationDetents([.height(540)])
}
