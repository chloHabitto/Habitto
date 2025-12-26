import SwiftUI

struct StreakModeView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ZStack(alignment: .bottom) {
        ScrollView {
          VStack(spacing: 24) {
            // Streak Mode Section
            streakModeSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 24)
          .padding(.bottom, 100) // Space for Save button
        }
        
        // Save button at bottom
        VStack(spacing: 0) {
          Divider()
          
          HabittoButton.largeFillPrimary(
            text: "Save",
            state: hasChanges ? .default : .disabled,
            action: {
              saveStreakMode()
            })
            .padding(24)
        }
        .background(Color.sheetBackground)
      }
      .background(Color.sheetBackground)
      .navigationTitle("Streak Mode")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var selectedMode: CompletionMode
  
  init() {
    // Initialize with current preference from CompletionMode
    _selectedMode = State(initialValue: CompletionMode.current)
  }
  
  private var hasChanges: Bool {
    selectedMode != CompletionMode.current
  }

  // MARK: - Streak Mode Section

  private var streakModeSection: some View {
    VStack(spacing: 0) {
      // Options
      VStack(spacing: 0) {
        streakModeRow(mode: .full, isSelected: selectedMode == .full)
        Divider()
          .padding(.leading, 60) // Account for icon (24) + spacing (16) + padding (20)
        streakModeRow(mode: .partial, isSelected: selectedMode == .partial)
      }
      .background(Color.surface)
      .cornerRadius(16)
    }
  }

  // MARK: - Streak Mode Row

  private func streakModeRow(mode: CompletionMode, isSelected: Bool) -> some View {
    Button(action: {
      selectedMode = mode
    }) {
      HStack(spacing: 16) {
        // Icon
        Image(mode.icon)
          .renderingMode(.template)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 24, height: 24)
          .foregroundColor(.appIconColor)
        
        VStack(alignment: .leading, spacing: 4) {
          Text(mode.displayName)
            .font(.appTitleMedium)
            .foregroundColor(.text01)

          Text(mode.description)
            .font(.appBodyMedium)
            .foregroundColor(.text04)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // Radio button
        ZStack {
          Circle()
            .stroke(isSelected ? Color.primary : Color(.systemGray4), lineWidth: 2)
            .frame(width: 20, height: 20)

          if isSelected {
            Circle()
              .fill(Color.primary)
              .frame(width: 10, height: 10)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func saveStreakMode() {
    // Save to CompletionMode.current (which persists to UserDefaults and posts notification)
    CompletionMode.current = selectedMode
    dismiss()
  }
}

#Preview {
  StreakModeView()
}

