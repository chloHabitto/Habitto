import SwiftUI

struct GoalBottomSheet: View {
    let onClose: () -> Void
    let onGoalSelected: (String) -> Void
    
    @State private var selectedGoalType: String = "Daily"
    @State private var selectedTab = 0
    @State private var dailyValue: Int = 1
    @State private var weeklyValue: Int = 1
    @State private var monthlyValue: Int = 1
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 1
    @State private var selectedSeconds: Int = 0
    
    private var selectedGoalText: String {
        if selectedTab == 0 {
            // Number tab
            return dailyValue == 1 ? "1 time" : "\(dailyValue) times"
        } else {
            // Time tab
            let totalSeconds = selectedHours * 3600 + selectedMinutes * 60 + selectedSeconds
            if totalSeconds == 0 {
                return "0 seconds"
            } else if totalSeconds < 60 {
                return "\(totalSeconds) seconds"
            } else if totalSeconds < 3600 {
                let minutes = totalSeconds / 60
                let seconds = totalSeconds % 60
                if seconds == 0 {
                    return "\(minutes) minutes"
                } else {
                    return "\(minutes) min \(seconds) sec"
                }
            } else {
                let hours = totalSeconds / 3600
                let remainingSeconds = totalSeconds % 3600
                let minutes = remainingSeconds / 60
                let seconds = remainingSeconds % 60
                if minutes == 0 && seconds == 0 {
                    return "\(hours) hours"
                } else if seconds == 0 {
                    return "\(hours) hr \(minutes) min"
                } else {
                    return "\(hours) hr \(minutes) min \(seconds) sec"
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            BottomSheetHeader(
                title: "Goal",
                description: "Set how many times or how long you want to do this habit for each session",
                onClose: onClose
            )
            
            // Spacing between header and tabs
            Spacer()
                .frame(height: 16)
            
            // Tab Menu
            TabMenu(
                selectedTab: $selectedTab,
                tabs: ["Number", "Time"]
            )
            
            // Content based on selected tab
            if selectedTab == 0 {
                // Daily tab
                VStack(spacing: 0) {
                    // 1. VStack: Text and Pill
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I want to achieve this goal")
                            .font(Font.titleMedium)
                            .foregroundColor(.text01)
                        
                        HStack {
                            Text(selectedGoalText)
                                .font(Font.bodyLarge)
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
                    
                    // 2. Divider
                    Divider()
                        .background(.outline)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                    
                    // 3. Stepper
                    VStack(spacing: 12) {
                        Spacer()
                            .frame(height: 16)
                        
                        HStack(spacing: 16) {
                            // Minus button
                            Button(action: {
                                if dailyValue > 1 { dailyValue -= 1 }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(dailyValue > 1 ? Color.white : .onDisabledBackground)
                                    .frame(width: 44, height: 44)
                                    .background(dailyValue > 1 ? .primary : .disabledBackground)
                                    .clipShape(Circle())
                            }
                            .frame(width: 48, height: 48)
                            .disabled(dailyValue <= 1)
                            
                            // Number display
                            Text("\(dailyValue)")
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
                                if dailyValue < 30 { dailyValue += 1 }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(dailyValue < 30 ? Color.white : .onDisabledBackground)
                                    .frame(width: 44, height: 44)
                                    .background(dailyValue < 30 ? .primary : .disabledBackground)
                                    .clipShape(Circle())
                            }
                            .frame(width: 48, height: 48)
                            .disabled(dailyValue >= 30)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // 4. Confirm button dock
                    VStack {
                        Button(action: {
                            onGoalSelected(selectedGoalText)
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
                // Time tab - same structure as Number tab
                VStack(spacing: 0) {
                    // 1. VStack: Text and Pill
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I want to achieve this goal")
                            .font(Font.titleMedium)
                            .foregroundColor(.text01)
                        
                        HStack {
                            Text(selectedGoalText)
                                .font(Font.bodyLarge)
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
                    
                    // 2. Divider
                    Divider()
                        .background(.outline)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                    
                    // 3. Countdown Timer Picker
                    VStack(spacing: 12) {
                        Spacer()
                            .frame(height: 16)
                        
                        CountdownTimerPicker(
                            hours: $selectedHours,
                            minutes: $selectedMinutes,
                            seconds: $selectedSeconds
                        )
                        .frame(height: 150)
                        .padding(.trailing, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    

                    
                    Spacer()
                    
                    // 4. Confirm button dock
                    VStack {
                        Button(action: {
                            onGoalSelected(selectedGoalText)
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
    GoalBottomSheet(
        onClose: {},
        onGoalSelected: { _ in }
    )
} 
