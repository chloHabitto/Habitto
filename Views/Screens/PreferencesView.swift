import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLanguage = false
    @State private var showingDateCalendar = false
    @State private var showingTheme = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Preferences",
                        description: "Customize your app experience"
                    ) {
                        dismiss()
                    }
                    
                    // App Preferences
                    VStack(spacing: 0) {
                        AccountOptionRow(
                            icon: "Icon-Language_Filled",
                            title: "Language",
                            subtitle: "Choose your preferred language",
                            hasChevron: true
                        ) {
                            showingLanguage = true
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        AccountOptionRow(
                            icon: "Icon-Calendar_Filled",
                            title: "Date & Calendar",
                            subtitle: "Set your date and calendar preferences",
                            hasChevron: true
                        ) {
                            showingDateCalendar = true
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        AccountOptionRow(
                            icon: "Icon-Theme_Filled",
                            title: "Theme",
                            subtitle: "Choose your preferred app theme",
                            hasChevron: true
                        ) {
                            showingTheme = true
                        }
                    }
                    .background(Color.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
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
        .sheet(isPresented: $showingLanguage) {
            LanguageView()
        }
        .sheet(isPresented: $showingDateCalendar) {
            DateCalendarView()
        }
        .sheet(isPresented: $showingTheme) {
            ThemeView()
        }
    }
}

#Preview {
    PreferencesView()
}
