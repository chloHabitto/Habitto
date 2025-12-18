import SwiftUI

struct ThemeView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ZStack(alignment: .bottom) {
        ScrollView {
          VStack(spacing: 24) {
            // Color Scheme Section
            colorSchemeSection
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
              saveTheme()
            })
            .padding(24)
        }
        .background(Color.sheetBackground)
      }
      .background(Color.sheetBackground)
      .navigationTitle("Theme")
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
    .preferredColorScheme(themeManager.preferredColorScheme)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var themeManager: ThemeManager
  @State private var selectedPreference: ColorSchemePreference
  
  init() {
    // Initialize with current preference
    _selectedPreference = State(initialValue: ThemeManager.shared.colorSchemePreference)
  }
  
  private var hasChanges: Bool {
    selectedPreference != themeManager.colorSchemePreference
  }

  // MARK: - Color Scheme Section

  private var colorSchemeSection: some View {
    VStack(spacing: 0) {
      // Section header
      HStack {
        Text("Appearance")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 16)

      // Options
      VStack(spacing: 0) {
        colorSchemeRow(preference: .system, isSelected: selectedPreference == .system)
        Divider()
          .padding(.leading, 60) // Account for icon (24) + spacing (16) + padding (20)
        colorSchemeRow(preference: .light, isSelected: selectedPreference == .light)
        Divider()
          .padding(.leading, 60) // Account for icon (24) + spacing (16) + padding (20)
        colorSchemeRow(preference: .dark, isSelected: selectedPreference == .dark)
      }
      .background(Color.surface)
      .cornerRadius(16)
    }
  }

  // MARK: - Color Scheme Row

  private func colorSchemeRow(preference: ColorSchemePreference, isSelected: Bool) -> some View {
    Button(action: {
      selectedPreference = preference
    }) {
      HStack(spacing: 16) {
        // Icon
        Image(systemName: preference.icon)
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(.primaryDim)
          .frame(width: 24, height: 24)
        
        VStack(alignment: .leading, spacing: 4) {
          Text(preference.displayName)
            .font(.appTitleMedium)
            .foregroundColor(.text01)

          Text(preference.description)
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
  
  private func saveTheme() {
    themeManager.colorSchemePreference = selectedPreference
    dismiss()
  }
}

// MARK: - ColorSchemePreference Extension

extension ColorSchemePreference {
  var description: String {
    switch self {
    case .system:
      "Match system appearance"
    case .light:
      "Always use light mode"
    case .dark:
      "Always use dark mode"
    }
  }
}

#Preview {
  ThemeView()
    .environmentObject(ThemeManager.shared)
}
