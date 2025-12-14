import SwiftUI

struct ThemeView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 24) {
            // Color Scheme Section
            colorSchemeSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 24)
          .padding(.bottom, 40)
        }
      }
      .background(Color.surface2)
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
    .preferredColorScheme(themeManager.colorScheme) // Apply selected color scheme to the sheet itself
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var themeManager: ThemeManager

  private var iconColor: Color {
    switch themeManager.selectedTheme {
    case .default:
      Color("navy200")
    case .black:
      Color("themeBlack200")
    case .purple:
      Color("themePurple200")
    case .pink:
      Color("themePink200")
    }
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
        colorSchemeRow(option: .system, isSelected: themeManager.selectedColorScheme == .system)
        Divider()
          .padding(.leading, 60) // Account for icon (24) + spacing (16) + padding (20)
        colorSchemeRow(option: .light, isSelected: themeManager.selectedColorScheme == .light)
        Divider()
          .padding(.leading, 60) // Account for icon (24) + spacing (16) + padding (20)
        colorSchemeRow(option: .dark, isSelected: themeManager.selectedColorScheme == .dark)
      }
      .background(Color.surface)
      .cornerRadius(16)
    }
  }

  // MARK: - Color Scheme Row

  private func colorSchemeRow(option: ColorSchemeOption, isSelected: Bool) -> some View {
    Button(action: {
      themeManager.selectedColorScheme = option
    }) {
      HStack(spacing: 16) {
        // Icon
        Image(option.iconName)
          .renderingMode(.template)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 24, height: 24)
          .foregroundColor(iconColor)
        
        VStack(alignment: .leading, spacing: 4) {
          Text(option.title)
            .font(.appTitleMedium)
            .foregroundColor(.text01)

          Text(option.description)
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
}

#Preview {
  ThemeView()
}
