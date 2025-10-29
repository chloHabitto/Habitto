import SwiftUI

struct PreferencesView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var themeManager: ThemeManager

  @State private var showingLanguage = false
  @State private var showingTheme = false

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

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // Description text
          Text("Customize your app experience")
            .font(.appBodyMedium)
            .foregroundColor(.text05)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)

          // App Preferences
          VStack(spacing: 0) {
            AccountOptionRow(
              icon: "Icon-Language_Filled",
              title: "Language",
              subtitle: "Choose your preferred language",
              hasChevron: true,
              iconColor: iconColor)
            {
              showingLanguage = true
            }

            Divider()
              .padding(.leading, 56)

            AccountOptionRow(
              icon: "Icon-Theme_Filled",
              title: "Theme",
              subtitle: "Choose your preferred app theme",
              hasChevron: true,
              iconColor: iconColor)
            {
              showingTheme = true
            }
          }
          .background(Color.surface)
          .cornerRadius(16)
          .padding(.horizontal, 20)

          // Note about upcoming updates
          Text("Language and theme will be updated soon")
            .font(.appBodySmall)
            .foregroundColor(.text03)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)

          Spacer(minLength: 24)
        }
        .padding(.horizontal, 0)
        .padding(.top, 0)
        .padding(.bottom, 20)
        .background(Color.surface2)
      }
      .background(Color.surface2)
      .navigationTitle("Preferences")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.text01)
          }
        }
      }
    }
    .sheet(isPresented: $showingLanguage) {
      LanguageView()
    }
    .sheet(isPresented: $showingTheme) {
      ThemeView()
    }
  }
}

#Preview {
  PreferencesView()
}
