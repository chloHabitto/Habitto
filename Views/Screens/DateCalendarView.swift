import SwiftUI

struct DateCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var datePreferences = DatePreferences.shared
    
    // Track original values to detect changes
    @State private var originalDateFormat: DateFormatOption
    @State private var originalFirstDay: FirstDayOption
    
    // Track current selections
    @State private var selectedDateFormat: DateFormatOption
    @State private var selectedFirstDay: FirstDayOption
    
    init() {
        let currentDateFormat = DatePreferences.shared.dateFormat
        let currentFirstDay = DatePreferences.shared.firstDayOfWeek
        
        self._originalDateFormat = State(initialValue: currentDateFormat)
        self._originalFirstDay = State(initialValue: currentFirstDay)
        self._selectedDateFormat = State(initialValue: currentDateFormat)
        self._selectedFirstDay = State(initialValue: currentFirstDay)
    }
    
    // Check if any changes were made
    private var hasChanges: Bool {
        return selectedDateFormat != originalDateFormat || selectedFirstDay != originalFirstDay
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content with save button
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Date Format Section
                            dateFormatSection
                            
                            // First Day of Week Section
                            firstDaySection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 100) // Extra bottom padding for save button
                    }
                    
                    // Save button at bottom
                    saveButton
                }
            }
            .background(Color.surface2)
            .navigationTitle("Date & Calendar")
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
    }
    
    // MARK: - Date Format Section
    private var dateFormatSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Date Format")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
            
            // Options container
            VStack(spacing: 0) {
                ForEach(Array(DateFormatOption.allCases.enumerated()), id: \.offset) { index, option in
                    dateFormatRow(option: option, isSelected: selectedDateFormat == option)
                    
                    if index < DateFormatOption.allCases.count - 1 {
                        Divider()
                            .background(Color(.systemGray4))
                            .padding(.leading, 20)
                    }
                }
            }
            .background(.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - First Day Section
    private var firstDaySection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("First Day of Week")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
            
            // Options container
            VStack(spacing: 0) {
                ForEach(Array(FirstDayOption.allCases.enumerated()), id: \.offset) { index, option in
                    firstDayRow(option: option, isSelected: selectedFirstDay == option)
                    
                    if index < FirstDayOption.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
            .background(.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Date Format Row
    private func dateFormatRow(option: DateFormatOption, isSelected: Bool) -> some View {
        Button(action: {
            selectedDateFormat = option
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.example)
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
    
    // MARK: - First Day Row
    private func firstDayRow(option: FirstDayOption, isSelected: Bool) -> some View {
        Button(action: {
            selectedFirstDay = option
        }) {
            HStack(spacing: 16) {
                Text(option.rawValue)
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
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
    
    // MARK: - Save Button
    private var saveButton: some View {
        VStack(spacing: 0) {
            // Gradient overlay to fade content behind button
            LinearGradient(
                gradient: Gradient(colors: [Color.surface2.opacity(0), Color.surface2]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            
            // Button container
            HStack {
                HabittoButton.largeFillPrimary(
                    text: "Save",
                    state: hasChanges ? .default : .disabled,
                    action: saveChanges
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(Color.surface2)
        }
    }
    
    // MARK: - Save Action
    private func saveChanges() {
        // Update the preferences with selected values
        datePreferences.dateFormat = selectedDateFormat
        datePreferences.firstDayOfWeek = selectedFirstDay
        
        // Update original values to reflect the new saved state
        originalDateFormat = selectedDateFormat
        originalFirstDay = selectedFirstDay
        
        // Dismiss the view
        dismiss()
    }
}

#Preview {
    DateCalendarView()
}
