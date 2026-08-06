import SwiftUI

// MARK: - LanguageView

struct LanguageView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Main content with save button
        ZStack(alignment: .bottom) {
          ScrollView {
            VStack(spacing: 24) {
              // Description text
              Text("language.description".localized)
                .font(.appBodyMedium)
                .foregroundColor(.text05)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

              // Language Selection Section
              languageSelectionSection

              Spacer(minLength: 24)
            }
            .padding(.horizontal, 0)
            .padding(.top, 0)
            .padding(.bottom, 100) // Extra bottom padding for save button
            .background(Color.sheetBackground)
          }

          // Save button at bottom
          saveButtonSection
        }
      }
      .background(Color.sheetBackground)
      .navigationTitle("language.title".localized)
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
      .onAppear {
        selectedLanguageCode = i18nManager.preferences.languageTag
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var i18nManager = I18nPreferencesManager.shared

  // State variables for language selection
  @State private var selectedLanguageCode: String = "en"
  @State private var showingLanguageDropdown = false

  /// Available languages with flags and native names
  private let languages = [
    LanguageOption(name: "English", flag: "🇬🇧", code: "en", nativeName: "English"),
    LanguageOption(name: "Korean", flag: "🇰🇷", code: "ko", nativeName: "한국어"),
    LanguageOption(name: "Japanese", flag: "🇯🇵", code: "ja", nativeName: "日本語"),
    LanguageOption(name: "Dutch", flag: "🇳🇱", code: "nl", nativeName: "Nederlands"),
    LanguageOption(name: "German", flag: "🇩🇪", code: "de", nativeName: "Deutsch"),
    LanguageOption(name: "Chinese", flag: "🇨🇳", code: "zh", nativeName: "中文"),
    LanguageOption(name: "Thai", flag: "🇹🇭", code: "th", nativeName: "ไทย")
  ]

  /// Check if any changes were made
  private var hasChanges: Bool {
    selectedLanguageCode != i18nManager.preferences.languageTag
  }

  /// Computed property for current language flag
  private var currentLanguageFlag: String {
    languages.first { $0.code == selectedLanguageCode }?.flag ?? "🇬🇧"
  }

  /// Computed property for current language native name
  private var currentLanguageNativeName: String {
    languages.first { $0.code == selectedLanguageCode }?.nativeName ?? "English"
  }

  /// Computed property for language selection section to simplify complex expression
  private var languageSelectionSection: some View {
    VStack(spacing: 0) {
      // Current Language Display
      currentLanguageDisplay

      // Language Dropdown Options
      if showingLanguageDropdown {
        languageDropdownOptions
      }
    }
  }

  /// Computed property for current language display
  private var currentLanguageDisplay: some View {
    HStack(spacing: 12) {
      // Flag
      Text(currentLanguageFlag)
        .font(.system(size: 24))
        .frame(width: 32, height: 32)

      VStack(alignment: .leading, spacing: 2) {
        Text("language.currentLanguage".localized)
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(.text04)

        Text(currentLanguageNativeName)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.text01)
      }

      Spacer()

      // Dropdown Arrow
      Image(systemName: showingLanguageDropdown ? "chevron.up" : "chevron.down")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.text04)
        .animation(.easeInOut(duration: 0.2), value: showingLanguageDropdown)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background(Color.surface)
    .cornerRadius(16)
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.2)) {
        showingLanguageDropdown.toggle()
      }
    }
    .padding(.horizontal, 20)
  }

  /// Computed property for language dropdown options
  private var languageDropdownOptions: some View {
    VStack(spacing: 0) {
      ForEach(languages, id: \.code) { language in
        languageOptionRow(for: language)

        if language.code != languages.last?.code {
          Divider()
            .padding(.leading, 64)
        }
      }
    }
    .background(Color.surface)
    .cornerRadius(16)
    .padding(.horizontal, 20)
    .transition(.opacity.combined(with: .move(edge: .top)))
  }

  /// Computed property for individual language option row
  private func languageOptionRow(for language: LanguageOption) -> some View {
    Button(action: {
      selectedLanguageCode = language.code
      withAnimation(.easeInOut(duration: 0.2)) {
        showingLanguageDropdown = false
      }
    }) {
      HStack(spacing: 12) {
        // Flag
        Text(language.flag)
          .font(.system(size: 24))
          .frame(width: 32, height: 32)

        VStack(alignment: .leading, spacing: 2) {
          Text(language.nativeName)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text01)

          Text(language.name)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(.text04)
        }

        Spacer()

        // Checkmark for selected language
        if selectedLanguageCode == language.code {
          Image(systemName: "checkmark")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.primary)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(selectedLanguageCode == language.code
        ? Color.primaryContainer.opacity(0.1)
        : Color.clear)
    }
  }

  /// Save button section at bottom
  private var saveButtonSection: some View {
    HStack {
      HabittoButton.largeFillPrimary(
        text: "language.save".localized,
        state: hasChanges ? .default : .disabled,
        action: saveLanguage)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 40)
  }

  /// Save language and post notification for parent to show toast
  private func saveLanguage() {
    guard FeatureFlags.inAppLanguageSwitchEnabled else { return }

    let selectedCode = selectedLanguageCode
    
    // Save to I18nPreferencesManager
    i18nManager.setLanguage(selectedCode)
    
    // Update LocalizationManager for immediate UI refresh
    LocalizationManager.shared.setLanguage(selectedCode)
    
    // Post notification with the success message in the selected language
    let message = getSuccessMessage(for: selectedCode)
    NotificationCenter.default.post(
      name: NSNotification.Name("ShowLanguageSavedToast"),
      object: nil,
      userInfo: ["message": message]
    )
    
    // Dismiss immediately
    dismiss()
  }

  /// Get localized success message for the selected language
  private func getSuccessMessage(for code: String) -> String {
    switch code {
    case "en":
      return "Language changed to English"
    case "ko":
      return "언어가 한국어로 변경되었습니다"
    case "ja":
      return "言語が日本語に変更されました"
    case "nl":
      return "Taal gewijzigd naar Nederlands"
    case "de":
      return "Sprache auf Deutsch geändert"
    case "zh":
      return "语言已更改为中文"
    case "th":
      return "เปลี่ยนภาษาเป็นภาษาไทยแล้ว"
    default:
      return "Language changed"
    }
  }
}

// MARK: - LanguageOption

struct LanguageOption {
  let name: String
  let flag: String
  let code: String
  let nativeName: String
}

#Preview {
  LanguageView()
}
