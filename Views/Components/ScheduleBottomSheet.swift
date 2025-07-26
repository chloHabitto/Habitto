import SwiftUI

struct ScheduleBottomSheet: View {
    let onClose: () -> Void
    let onScheduleSelected: (String) -> Void
    
    @State private var selectedSchedule: String = "Daily"
    @State private var selectedTab = 0
    @State private var selectedDays: String = "Everyday"
    @State private var selectedWeekDays: Set<String> = []
    
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
                            onScheduleSelected(selectedSchedule)
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
                VStack(spacing: 12) {
                    Text("Frequency options will go here")
                        .font(Font.bodyLarge)
                        .foregroundColor(.text04)
                        .padding(.top, 16)
                    Spacer()
                }
                .padding(.horizontal, 16)
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
