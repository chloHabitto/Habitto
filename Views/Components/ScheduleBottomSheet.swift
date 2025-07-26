import SwiftUI

struct ScheduleBottomSheet: View {
    let onClose: () -> Void
    let onScheduleSelected: (String) -> Void
    
    @State private var selectedSchedule: String = "Daily"
    @State private var selectedTab = 0
    
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
                            .font(.titleMedium)
                            .foregroundColor(.text01)
                        
                        HStack {
                            Text("Everyday")
                                .font(.bodyLarge)
                                .foregroundColor(.onPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "1C274C"))
                                .clipShape(Capsule())
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

                    // 4. iOS scrollable date picker
                    VStack(spacing: 12) {
                        DatePicker(
                            "Select frequency",
                            selection: .constant(Date()),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // 5. Confirm button dock
                    VStack {
                        Button(action: {
                            onScheduleSelected(selectedSchedule)
                            onClose()
                        }) {
                            Text("Confirm")
//                                .font(.buttonText1)
//                                .foregroundColor(.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
//                                .background(.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            } else {
                // Frequency tab
                VStack(spacing: 12) {
                    Text("Frequency options will go here")
                        .font(.bodyLarge)
                        .foregroundColor(.text04)
                        .padding(.top, 16)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            Spacer()
        }
        .background(.surface)
    }
}

#Preview {
    ScheduleBottomSheet(
        onClose: {},
        onScheduleSelected: { _ in }
    )
} 
