import SwiftUI

struct DateCalendarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDateFormat: DateFormatOption = .dayMonthYear
    @State private var selectedFirstDay: FirstDayOption = .monday
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            topNavigationBar
            
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Date Format Section
                    dateFormatSection
                    
                    // First Day of Week Section
                    firstDaySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        VStack(spacing: 0) {
            HStack {
                // Back button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text("Date & Calendar")
                    .font(.appHeadlineMediumEmphasised)
                    .foregroundColor(.text01)
                
                Text("Customize date format and calendar preferences.")
                    .font(.appTitleSmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .padding(.top, 0) // Let the system handle safe area
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
                
                Spacer()
                
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
                
                Spacer()
                
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Models
enum DateFormatOption: CaseIterable {
    case dayMonthYear
    case monthDayYear
    case yearMonthDay
    
    var example: String {
        switch self {
        case .dayMonthYear:
            return "31/12/2025"
        case .monthDayYear:
            return "12/31/2025"
        case .yearMonthDay:
            return "2025-12-31"
        }
    }
    
    var description: String {
        switch self {
        case .dayMonthYear:
            return "Day/Month/Year"
        case .monthDayYear:
            return "Month/Day/Year"
        case .yearMonthDay:
            return "Year/Month/Day"
        }
    }
}

enum FirstDayOption: String, CaseIterable {
    case monday = "Monday"
    case sunday = "Sunday"
}

#Preview {
    DateCalendarSettingsView()
}
