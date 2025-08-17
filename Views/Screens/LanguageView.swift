import SwiftUI

struct LanguageView: View {
    @Environment(\.dismiss) private var dismiss
    
    // State variables for language selection
    @State private var selectedLanguage = "English"
    @State private var showingLanguageDropdown = false
    
    // Available languages with flags
    private let languages = [
        LanguageOption(name: "English", flag: "🇬🇧", code: "en"),
        LanguageOption(name: "Korean", flag: "🇰🇷", code: "ko"),
        LanguageOption(name: "Japanese", flag: "🇯🇵", code: "ja")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Language",
                        description: "Choose your preferred language"
                    ) {
                        dismiss()
                    }
                    
                    // Language Selection Section
                    languageSelectionSection
                    
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 0)
                .padding(.top, 0)
                .padding(.bottom, 20)
                .background(Color.surface2)
            }
            .background(Color.surface2)
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
    }
    
    // Computed property for current language flag
    private var currentLanguageFlag: String {
        languages.first { $0.name == selectedLanguage }?.flag ?? "🇬🇧"
    }
    
    // Computed property for language selection section to simplify complex expression
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
    
    // Computed property for current language display
    private var currentLanguageDisplay: some View {
        HStack(spacing: 12) {
            // Flag
            Text(currentLanguageFlag)
                .font(.system(size: 24))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Language")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.text04)
                
                Text(selectedLanguage)
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
    
    // Computed property for language dropdown options
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
    
    // Computed property for individual language option row
    private func languageOptionRow(for language: LanguageOption) -> some View {
        Button(action: {
            selectedLanguage = language.name
            withAnimation(.easeInOut(duration: 0.2)) {
                showingLanguageDropdown = false
            }
            // TODO: Implement language change functionality
        }) {
            HStack(spacing: 12) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                    
                    Text(language.code.uppercased())
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.text04)
                }
                
                Spacer()
                
                // Checkmark for selected language
                if selectedLanguage == language.name {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(selectedLanguage == language.name ? Color.primaryContainer.opacity(0.1) : Color.clear)
        }
    }
}

// MARK: - Language Option Model
struct LanguageOption {
    let name: String
    let flag: String
    let code: String
}

#Preview {
    LanguageView()
}
