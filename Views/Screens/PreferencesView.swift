import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingLanguage = false
    @State private var showingDateCalendar = false
    @State private var showingTheme = false
    @State private var showingDailyReminders = false
    
    private var iconColor: Color {
        themeManager.selectedTheme == .default ? Color("navy200") : Color("themeBlack200")
    }
    
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
                            hasChevron: true,
                            iconColor: iconColor
                        ) {
                            showingLanguage = true
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        AccountOptionRow(
                            icon: "Icon-Calendar_Filled",
                            title: "Date & Calendar",
                            subtitle: "Set your date and calendar preferences",
                            hasChevron: true,
                            iconColor: iconColor
                        ) {
                            showingDateCalendar = true
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        AccountOptionRow(
                            icon: "Icon-Theme_Filled",
                            title: "Theme",
                            subtitle: "Choose your preferred app theme",
                            hasChevron: true,
                            iconColor: iconColor
                        ) {
                            showingTheme = true
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        AccountOptionRow(
                            icon: "Icon-alarm_Filled",
                            title: "Daily Reminders",
                            subtitle: "Set up your daily habit reminders",
                            hasChevron: true,
                            iconColor: iconColor
                        ) {
                            showingDailyReminders = true
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
        .sheet(isPresented: $showingDailyReminders) {
            DailyRemindersView()
        }
    }
}

#Preview {
    PreferencesView()
}
