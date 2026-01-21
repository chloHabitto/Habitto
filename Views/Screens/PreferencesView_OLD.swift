import SwiftUI

struct PreferencesView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var themeManager: ThemeManager

  @State private var showingLanguage = false
  @State private var showingTheme = false
  @State private var showingDateCalendar = false
  @State private var showingStreakMode = false

  private var iconColor: Color {
    Color.appIconColor
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
              .background(Color(.systemGray4))
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
            
            Divider()
              .background(Color(.systemGray4))
              .padding(.leading, 56)
            
            AccountOptionRow(
              icon: "Icon-Calendar_Filled",
              title: "Date & Calendar",
              subtitle: "Customise date format & calendar",
              hasChevron: true,
              iconColor: iconColor)
            {
              showingDateCalendar = true
            }
            
            Divider()
              .background(Color(.systemGray4))
              .padding(.leading, 56)
            
            AccountOptionRow(
              icon: "Icon-flag-filled",
              title: "Streak Mode",
              subtitle: "Define what counts as a completed day",
              hasChevron: true,
              iconColor: iconColor)
            {
              showingStreakMode = true
            }
          }
          .background(Color("appSurface02Variant"))
          .cornerRadius(24)
          .padding(.horizontal, 20)

          Spacer(minLength: 24)
        }
        .padding(.horizontal, 0)
        .padding(.top, 0)
        .padding(.bottom, 20)
        .background(Color("appSurface01Variant02"))
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Preferences")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .heavy))
              .foregroundColor(.appInverseSurface70)
              .foregroundColor(.text01)
          }
        }
      }
    }
    .preferredColorScheme(themeManager.preferredColorScheme)
    .sheet(isPresented: $showingLanguage) {
      LanguageView()
    }
    .sheet(isPresented: $showingTheme) {
      ThemeView()
    }
    .sheet(isPresented: $showingDateCalendar) {
      DateCalendarView()
    }
    .sheet(isPresented: $showingStreakMode) {
      StreakModeView()
    }
  }
}

#Preview {
  PreferencesView()
}
