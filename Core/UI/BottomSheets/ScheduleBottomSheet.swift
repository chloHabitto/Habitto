import SwiftUI

struct ScheduleBottomSheet: View {
    let onClose: () -> Void
    let onScheduleSelected: (String) -> Void
    let initialSchedule: String?
    
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
    
    init(onClose: @escaping () -> Void, onScheduleSelected: @escaping (String) -> Void, initialSchedule: String? = nil) {
        self.onClose = onClose
        self.onScheduleSelected = onScheduleSelected
        self.initialSchedule = initialSchedule
    }
    
    private var pillTexts: [String] {
        // Sort days in chronological order (Mon -> Sun), not alphabetically
        let weekdayOrder = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        let sortedDays = selectedWeekDays.sorted { day1, day2 in
            let index1 = weekdayOrder.firstIndex(of: day1) ?? 0
            let index2 = weekdayOrder.firstIndex(of: day2) ?? 0
            return index1 < index2
        }
        return sortedDays.compactMap { day in
            ScheduleOptions.dayMapping[day]
        }
    }
    
    private var frequencyPillTexts: [String] {
        // Sort days in chronological order (Mon -> Sun), not alphabetically
        let weekdayOrder = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        let sortedDays = selectedFrequencyWeekDays.sorted { day1, day2 in
            let index1 = weekdayOrder.firstIndex(of: day1) ?? 0
            let index2 = weekdayOrder.firstIndex(of: day2) ?? 0
            return index1 < index2
        }
        return sortedDays.compactMap { day in
            ScheduleOptions.dayMapping[day]
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
                return "\(weeklyValue) day\(weeklyValue == 1 ? "" : "s") a week"
            } else if selectedFrequency == "Monthly" {
                return "\(monthlyValue) day\(monthlyValue == 1 ? "" : "s") a month"
            }
        }
        return "Not Selected"
    }
    
    private let scheduleOptions = ScheduleOptions.scheduleOptions
    private let dayOptions = ScheduleOptions.dayOptions
    private let frequencyOptions = ScheduleOptions.frequencyOptions
    
    private func parseAndSetInitialSchedule(_ schedule: String) {
        print("🔍 SCHEDULE SHEET INIT - Parsing schedule: '\(schedule)'")
        
        let lowercasedSchedule = schedule.lowercased()
        
        // Check if it's a specific weekday selection (e.g., "every monday, every friday")
        if lowercasedSchedule.contains("every") && (lowercasedSchedule.contains("monday") || 
           lowercasedSchedule.contains("tuesday") || lowercasedSchedule.contains("wednesday") || 
           lowercasedSchedule.contains("thursday") || lowercasedSchedule.contains("friday") || 
           lowercasedSchedule.contains("saturday") || lowercasedSchedule.contains("sunday")) {
            
            // Set to Interval tab, Weekly option
            selectedTab = 0
            selectedSchedule = "Weekly"
            
            // Parse the days
            var parsedDays: Set<String> = []
            let dayMappingReverse: [String: String] = [
                "monday": "MON",
                "tuesday": "TUE", 
                "wednesday": "WED",
                "thursday": "THU",
                "friday": "FRI",
                "saturday": "SAT",
                "sunday": "SUN"
            ]
            
            for (fullDay, shortDay) in dayMappingReverse {
                if lowercasedSchedule.contains(fullDay) {
                    parsedDays.insert(shortDay)
                    print("🔍 SCHEDULE SHEET INIT - Found \(fullDay) → \(shortDay)")
                }
            }
            
            selectedWeekDays = parsedDays
            print("🔍 SCHEDULE SHEET INIT - Set selectedWeekDays: \(selectedWeekDays)")
            
        } else if lowercasedSchedule.contains("days a week") {
            // Handle frequency-based schedules like "2 days a week"
            selectedTab = 1 // Frequency tab
            selectedFrequency = "Weekly"
            
            // Extract the number
            if let number = extractNumber(from: schedule) {
                weeklyValue = number
                print("🔍 SCHEDULE SHEET INIT - Set weeklyValue: \(weeklyValue)")
            }
            
        } else if lowercasedSchedule.contains("days a month") {
            // Handle monthly frequency schedules like "3 days a month"
            selectedTab = 1 // Frequency tab
            selectedFrequency = "Monthly"
            
            // Extract the number
            if let number = extractNumber(from: schedule) {
                monthlyValue = number
                print("🔍 SCHEDULE SHEET INIT - Set monthlyValue: \(monthlyValue)")
            }
            
        } else {
            // Handle basic daily schedules like "Everyday", "Weekdays", "Weekends"
            selectedTab = 0 // Interval tab
            selectedSchedule = "Daily"
            selectedDays = schedule
            print("🔍 SCHEDULE SHEET INIT - Set daily schedule: \(schedule)")
        }
    }
    
    private func extractNumber(from schedule: String) -> Int? {
        let pattern = #"(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) else {
            return nil
        }
        
        let range = match.range(at: 1)
        let numberString = (schedule as NSString).substring(with: range)
        return Int(numberString)
    }
    
    var body: some View {
        BaseBottomSheet(
            title: "Schedule",
            description: "Set which day(s) you'd like to do this habit",
            onClose: onClose,
            confirmButton: {
                onScheduleSelected(selectedScheduleText)
                onClose()
            },
            confirmButtonTitle: "Confirm"
        ) {
            VStack(spacing: 0) {
                // Tab Menu
                TabMenu(
                    selectedTab: $selectedTab,
                    tabs: ["Interval", "Frequency"]
                )
                
                // Content based on selected tab
                if selectedTab == 0 {
                    VStack(spacing: 0) {
                        // 1. VStack: Text and Pill
                        VStack(alignment: .leading, spacing: 12) {
                            Text("I want to repeat this habit")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            HStack {
                                if selectedSchedule == "Weekly" {
                                    if pillTexts.isEmpty {
                                        Text("Select days")
                                            .font(.appBodyLarge)
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
                                                        .font(.appBodyLarge)
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
                                        .font(.appBodyLarge)
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
                            .background(.outline3)
                            .padding(.vertical, 20)
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
                                    .font(.appTitleSmall)
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
                                                .font(.appLabelMediumEmphasised)
                                                .foregroundColor(selectedWeekDays.contains(day) ? .onPrimary : .onSecondaryContainer)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(selectedWeekDays.contains(day) ? .primary : .secondaryContainer)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(.outline3, lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        Spacer()
                    }
                } else {
                    // Frequency tab
                    VStack(spacing: 0) {
                        // 1. VStack: Text and Pill
                        VStack(alignment: .leading, spacing: 12) {
                            Text("I want to repeat this habit")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            HStack {
                                if selectedFrequency == "Monthly" {
                                    Text(monthlyValue == 1 ? "1 day a month" : "\(monthlyValue) days a month")
                                        .font(.appBodyLarge)
                                        .foregroundColor(.onPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "1C274C"))
                                        .clipShape(Capsule())
                                } else {
                                    Text(weeklyValue == 1 ? "1 day a week" : "\(weeklyValue) days a week")
                                        .font(.appBodyLarge)
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
                            .background(.outline3)
                            .padding(.vertical, 20)
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
                                            .font(.appTitleMedium)
                                            .foregroundColor(monthlyValue > 1 ? Color.white : .onDisabledBackground)
                                            .frame(width: 44, height: 44)
                                            .background(monthlyValue > 1 ? .primary : .disabledBackground)
                                            .clipShape(Circle())
                                    }
                                    .frame(width: 48, height: 48)
                                    .disabled(monthlyValue <= 1)
                                    
                                    // Number display
                                    Text("\(monthlyValue)")
                                        .font(.appHeadlineSmallEmphasised)
                                        .foregroundColor(.text01)
                                        .frame(width: 52, height: 52)
                                        .background(.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(.outline3, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    // Plus button
                                    Button(action: {
                                        if monthlyValue < 30 {
                                            monthlyValue += 1
                                        }
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.appTitleMedium)
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
                                            .font(.appTitleMedium)
                                            .foregroundColor(weeklyValue > 1 ? Color.white : .onDisabledBackground)
                                            .frame(width: 44, height: 44)
                                            .background(weeklyValue > 1 ? .primary : .disabledBackground)
                                            .clipShape(Circle())
                                    }
                                    .frame(width: 48, height: 48)
                                    .disabled(weeklyValue <= 1)
                                    
                                    // Number display
                                    Text("\(weeklyValue)")
                                        .font(.appHeadlineSmallEmphasised)
                                        .foregroundColor(.text01)
                                        .frame(width: 52, height: 52)
                                        .background(.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(.outline3, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    // Plus button
                                    Button(action: {
                                        if weeklyValue < 7 {
                                            weeklyValue += 1
                                        }
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.appTitleMedium)
                                            .foregroundColor(weeklyValue < 7 ? Color.white : .onDisabledBackground)
                                            .frame(width: 44, height: 44)
                                            .background(weeklyValue < 7 ? .primary : .disabledBackground)
                                            .clipShape(Circle())
                                    }
                                    .frame(width: 48, height: 48)
                                    .disabled(weeklyValue >= 7)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        
                        Spacer()
                    }
                }
                Spacer()
            }
        }
        .presentationDetents([.large, .height(700)])
        .onAppear {
            // Initialize schedule if editing
            if let initialSchedule = initialSchedule {
                parseAndSetInitialSchedule(initialSchedule)
            }
        }
    }
}

#Preview {
    ScheduleBottomSheet(
        onClose: {},
        onScheduleSelected: { _ in }
    )
} 
