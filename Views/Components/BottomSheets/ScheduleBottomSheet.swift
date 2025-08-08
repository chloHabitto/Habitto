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
        let sortedDays = selectedWeekDays.sorted()
        return sortedDays.compactMap { day in
            ScheduleOptions.dayMapping[day]
        }
    }
    
    private var frequencyPillTexts: [String] {
        let sortedDays = selectedFrequencyWeekDays.sorted()
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
                return "\(weeklyValue) times a week"
            } else if selectedFrequency == "Monthly" {
                return "\(monthlyValue) times a month"
            }
        }
        return "Not Selected"
    }
    
    private let scheduleOptions = ScheduleOptions.scheduleOptions
    private let dayOptions = ScheduleOptions.dayOptions
    private let frequencyOptions = ScheduleOptions.frequencyOptions
    
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
                            .background(.outline)
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
                                                        .stroke(.outline, lineWidth: 1)
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
                                    Text(monthlyValue == 1 ? "1 time a month" : "\(monthlyValue) times a month")
                                        .font(.appBodyLarge)
                                        .foregroundColor(.onPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "1C274C"))
                                        .clipShape(Capsule())
                                } else {
                                    Text(weeklyValue == 1 ? "1 time a week" : "\(weeklyValue) times a week")
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
                            .background(.outline)
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
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(.outline, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                    
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
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(.outline, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                    
                                    // Plus button
                                    Button(action: {
                                        if weeklyValue < 30 {
                                            weeklyValue += 1
                                        }
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.appTitleMedium)
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
                    }
                }
                Spacer()
            }
        }
        .presentationDetents([.large, .height(700)])
        .onAppear {
            // Initialize schedule if editing
            if let initialSchedule = initialSchedule {
                selectedDays = initialSchedule
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
