import SwiftUI

struct ScheduleBottomSheet: View {
    let onClose: () -> Void
    let onScheduleSelected: (String) -> Void
    
    @State private var selectedSchedule: String = "Daily"
    @State private var selectedTab = 0
    @State private var selectedDays: String = "Everyday"
    @State private var selectedWeekDays: Set<String> = []
    
    // Frequency tab state
    @State private var selectedFrequency: String = "Weekly"
    @State private var selectedFrequencyDays: String = "Every week"
    @State private var selectedFrequencyWeekDays: Set<String> = []
    @State private var weeklyValue: Int = 1
    @State private var monthlyValue: Int = 1
    
    private static let dayMapping = [
        "MON": "Every Monday",
        "TUE": "Every Tuesday", 
        "WED": "Every Wednesday",
        "THU": "Every Thursday",
        "FRI": "Every Friday",
        "SAT": "Every Saturday",
        "SUN": "Every Sunday"
    ]
    
    private var pillTexts: [String] {
        let sortedDays = selectedWeekDays.sorted()
        return sortedDays.compactMap { day in
            Self.dayMapping[day]
        }
    }
    
    private var frequencyPillTexts: [String] {
        let sortedDays = selectedFrequencyWeekDays.sorted()
        return sortedDays.compactMap { day in
            Self.dayMapping[day]
        }
    }
    
    private var selectedScheduleText: String {
        if selectedTab == 0 {
            // Repeat tab
            if selectedSchedule == "Daily" {
                return selectedDays
            } else if selectedSchedule == "Weekly" {
                if selectedWeekDays.isEmpty {
                    return "Select days"
                } else {
                    return pillTexts.joined(separator: ", ")
                }
            }
        } else {
            // Frequency tab
            if selectedFrequency == "Weekly" {
                return "\(weeklyValue) times a week"
            } else if selectedFrequency == "Monthly" {
                return "\(monthlyValue) times a month"
            }
        }
        return "Not Selected"
    }
    
    private let scheduleOptions: [String] = [
        "Everyday",
        "Weekdays",
        "Weekends",
        "Monday",
        "Tuesday", 
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
    ]
    
    private let dayOptions = [
        "Everyday", "Every 2 days", "Every 3 days", "Every 4 days", "Every 5 days", "Every 6 days", "Every 7 days", 
        "Every 8 days", "Every 9 days", "Every 10 days", "Every 11 days", "Every 12 days", "Every 13 days", "Every 14 days", 
        "Every 15 days", "Every 16 days", "Every 17 days", "Every 18 days", "Every 19 days", "Every 20 days", 
        "Every 21 days", "Every 22 days", "Every 23 days", "Every 24 days", "Every 25 days", "Every 26 days", 
        "Every 27 days", "Every 28 days", "Every 29 days", "Every 30 days"
    ]
    
    private let frequencyOptions = [
        "Every week", "Every 2 weeks", "Every 3 weeks", "Every 4 weeks", "Every 5 weeks", "Every 6 weeks", "Every 7 weeks", 
        "Every 8 weeks", "Every 9 weeks", "Every 10 weeks", "Every 11 weeks", "Every 12 weeks", "Every 13 weeks", "Every 14 weeks", 
        "Every 15 weeks", "Every 16 weeks", "Every 17 weeks", "Every 18 weeks", "Every 19 weeks", "Every 20 weeks", 
        "Every 21 weeks", "Every 22 weeks", "Every 23 weeks", "Every 24 weeks", "Every 25 weeks", "Every 26 weeks", 
        "Every 27 weeks", "Every 28 weeks", "Every 29 weeks", "Every 30 weeks"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            BottomSheetHeader(
                title: "Schedule",
                description: "Set which day(s) you'd like to do this habit",
                onClose: onClose
            )
            
            // Spacing between header and tabs
            Spacer()
                .frame(height: 16)
            
            // Tab Menu
            TabMenu(
                selectedTab: $selectedTab,
                tabs: ["Repeat", "Frequency"]
            )
            
            // Content based on selected tab
            if selectedTab == 0 {
                VStack(spacing: 0) {
                    // 1. VStack: Text and Pill
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I want to repeat this habit")
                            .font(Font.titleMedium)
                            .foregroundColor(.text01)
                        
                        HStack {
                            if selectedSchedule == "Weekly" {
                                if pillTexts.isEmpty {
                                    Text("Select days")
                                        .font(Font.bodyLarge)
                                        .foregroundColor(.onPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "1C274C"))
                                        .clipShape(Capsule())
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(pillTexts, id: \.self) { pillText in
                                                Text(pillText)
                                                    .font(Font.bodyLarge)
                                                    .foregroundColor(.onPrimary)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(Color(hex: "1C274C"))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            } else {
                                Text(selectedDays)
                                    .font(Font.bodyLarge)
                                    .foregroundColor(.onPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "1C274C"))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
//                    .background(.red)

                    // 2. Divider
                    Divider()
                        .background(.outline)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)

                    // 3. Segmented Picker
                    VStack(spacing: 12) {
                        Picker("Frequency", selection: $selectedSchedule) {
                            Text("Daily").tag("Daily")
                            Text("Weekly").tag("Weekly")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal, 16)

                    // Weekly days selection (only show when Weekly is selected)
                    if selectedSchedule == "Weekly" {
                        VStack(alignment: .leading, spacing: 12) {
                            Spacer()
                                .frame(height: 16)
                            
                            Text("On those days")
                                .font(Font.titleSmall)
                                .foregroundColor(.text05)
                            
                            HStack(spacing: 8) {
                                ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { day in
                                    Button(action: {
                                        if selectedWeekDays.contains(day) {
                                            selectedWeekDays.remove(day)
                                        } else {
                                            selectedWeekDays.insert(day)
                                        }
                                    }) {
                                        Text(day)
                                            .font(Font.labelMediumEmphasised)
                                            .foregroundColor(selectedWeekDays.contains(day) ? .onPrimary : .onSecondaryContainer)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(selectedWeekDays.contains(day) ? .primary : .secondaryContainer)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(.outline, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .background(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // 4. iOS scrollable date picker (only show when Daily is selected)
                    if selectedSchedule == "Daily" {
                        VStack(spacing: 12) {
                            Picker("Frequency", selection: $selectedDays) {
                                ForEach(dayOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .labelsHidden()
                        }
//                        .background(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    Spacer()

                    // 5. Confirm button dock
                    VStack {
                        Button(action: {
                            onScheduleSelected(selectedScheduleText)
                            onClose()
                        }) {
                            Text("Confirm")
                                .font(Font.buttonText1)
                                .foregroundColor(.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "1C274C"))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .background(.white)
                    .overlay(
                        Rectangle()
                            .fill(.outline)
                            .frame(height: 1),
                        alignment: .top
                    )
                }
            } else {
                // Frequency tab
                VStack(spacing: 0) {
                    // 1. VStack: Text and Pill
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I want to repeat this habit")
                            .font(Font.titleMedium)
                            .foregroundColor(.text01)
                        
                        HStack {
                            if selectedFrequency == "Monthly" {
                                Text(monthlyValue == 1 ? "1 time a month" : "\(monthlyValue) times a month")
                                    .font(Font.bodyLarge)
                                    .foregroundColor(.onPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "1C274C"))
                                    .clipShape(Capsule())
                            } else {
                                Text(weeklyValue == 1 ? "1 time a week" : "\(weeklyValue) times a week")
                                    .font(Font.bodyLarge)
                                    .foregroundColor(.onPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "1C274C"))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    
                    // 2. Divider
                    Divider()
                        .background(.outline)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                    
                    // 3. Segmented Picker
                    VStack(spacing: 12) {
                        Picker("Frequency", selection: $selectedFrequency) {
                            Text("Weekly").tag("Weekly")
                            Text("Monthly").tag("Monthly")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal, 16)
                    
                    // Monthly stepper (only show when Monthly is selected)
                    if selectedFrequency == "Monthly" {
                        VStack(spacing: 12) {
                            Spacer()
                                .frame(height: 16)
                            
                            HStack(spacing: 16) {
                                // Minus button
                                Button(action: {
                                    if monthlyValue > 1 {
                                        monthlyValue -= 1
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(monthlyValue > 1 ? Color.white : .onDisabledBackground)
                                        .frame(width: 44, height: 44)
                                        .background(monthlyValue > 1 ? .primary : .disabledBackground)
                                        .clipShape(Circle())
                                }
                                .frame(width: 48, height: 48)
                                .disabled(monthlyValue <= 1)
                                
                                // Number display
                                Text("\(monthlyValue)")
                                    .font(Font.headlineSmallEmphasised)
                                    .foregroundColor(.text01)
                                    .frame(width: 52, height: 52)
                                    .background(.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.outline, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                // Plus button
                                Button(action: {
                                    if monthlyValue < 30 {
                                        monthlyValue += 1
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(monthlyValue < 30 ? Color.white : .onDisabledBackground)
                                        .frame(width: 44, height: 44)
                                        .background(monthlyValue < 30 ? .primary : .disabledBackground)
                                        .clipShape(Circle())
                                }
                                .frame(width: 48, height: 48)
                                .disabled(monthlyValue >= 30)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    // 4. Stepper (only show when Weekly is selected)
                    if selectedFrequency == "Weekly" {
                        VStack(spacing: 12) {
                            Spacer()
                                .frame(height: 16)
                            
                            HStack(spacing: 16) {
                                // Minus button
                                Button(action: {
                                    if weeklyValue > 1 {
                                        weeklyValue -= 1
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(weeklyValue > 1 ? Color.white : .onDisabledBackground)
                                        .frame(width: 44, height: 44)
                                        .background(weeklyValue > 1 ? .primary : .disabledBackground)
                                        .clipShape(Circle())
                                }
                                .frame(width: 48, height: 48)
                                .disabled(weeklyValue <= 1)
                                
                                // Number display
                                Text("\(weeklyValue)")
                                    .font(Font.headlineSmallEmphasised)
                                    .foregroundColor(.text01)
                                    .frame(width: 52, height: 52)
                                    .background(.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.outline, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                // Plus button
                                Button(action: {
                                    if weeklyValue < 30 {
                                        weeklyValue += 1
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(weeklyValue < 30 ? Color.white : .onDisabledBackground)
                                        .frame(width: 44, height: 44)
                                        .background(weeklyValue < 30 ? .primary : .disabledBackground)
                                        .clipShape(Circle())
                                }
                                .frame(width: 48, height: 48)
                                .disabled(weeklyValue >= 30)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // 5. Confirm button dock
                    VStack {
                        Button(action: {
                            onScheduleSelected(selectedScheduleText)
                            onClose()
                        }) {
                            Text("Confirm")
                                .font(Font.buttonText1)
                                .foregroundColor(.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "1C274C"))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .background(.white)
                    .overlay(
                        Rectangle()
                            .fill(.outline)
                            .frame(height: 1),
                        alignment: .top
                    )
                }
            }
            Spacer()
        }
        .background(.surface)
        .presentationDetents([.large, .height(600)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }
}

#Preview {
    ScheduleBottomSheet(
        onClose: {},
        onScheduleSelected: { _ in }
    )
} 
