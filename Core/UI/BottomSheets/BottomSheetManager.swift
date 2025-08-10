import SwiftUI

// MARK: - Bottom Sheet Manager

class BottomSheetManager: ObservableObject {
    @Published var isShowingSheet = false
    @Published var currentSheet: BottomSheetType?
    
    enum BottomSheetType {
        case color(onColorSelected: (Color) -> Void)
        case schedule(onScheduleSelected: (String) -> Void, currentSchedule: String)
        case goal(onGoalSelected: (String) -> Void, currentGoal: String)
        case reminder(onReminderSelected: (String) -> Void, initialReminders: [ReminderItem], onRemindersUpdated: ([ReminderItem]) -> Void)
        case period(onPeriodSelected: (Date, Date?) -> Void, startDate: Date, endDate: Date?)
        case icon(onIconSelected: (String) -> Void, currentIcon: String)
        case custom(config: BottomSheetConfig, onOptionSelected: (BottomSheetOption) -> Void)
    }
    
    func showSheet(_ type: BottomSheetType) {
        currentSheet = type
        isShowingSheet = true
    }
    
    func dismissSheet() {
        isShowingSheet = false
        currentSheet = nil
    }
}

// MARK: - Bottom Sheet Container View

struct BottomSheetContainer: View {
    @ObservedObject var manager: BottomSheetManager
    
    var body: some View {
        Group {
            if let sheetType = manager.currentSheet {
                switch sheetType {
                case .color(let onColorSelected):
                    AnyView(ColorBottomSheet(
                        onClose: { manager.dismissSheet() },
                        onColorSelected: { color in
                            onColorSelected(color)
                            manager.dismissSheet()
                        }
                    ))

                case .schedule(let onScheduleSelected, let currentSchedule):
                    AnyView(ConfigurableBottomSheet(
                        config: .scheduleConfig(selectedSchedule: currentSchedule),
                        onClose: { manager.dismissSheet() },
                        onOptionSelected: { option in
                            if let value = option.value as? String {
                                onScheduleSelected(value)
                                manager.dismissSheet()
                            }
                        }
                    ))

                case .goal(let onGoalSelected, let currentGoal):
                    AnyView(ConfigurableBottomSheet(
                        config: .goalConfig(selectedGoal: currentGoal),
                        onClose: { manager.dismissSheet() },
                        onOptionSelected: { option in
                            if let value = option.value as? String {
                                onGoalSelected(value)
                                manager.dismissSheet()
                            }
                        }
                    ))

                case .reminder(let onReminderSelected, let initialReminders, let onRemindersUpdated):
                    AnyView(ReminderBottomSheet(
                        onClose: { manager.dismissSheet() },
                        onReminderSelected: onReminderSelected,
                        initialReminders: initialReminders,
                        onRemindersUpdated: onRemindersUpdated
                    ))

                case .period(let onPeriodSelected, let startDate, let endDate):
                    AnyView(PeriodBottomSheet(
                        isSelectingStartDate: endDate == nil,
                        startDate: startDate,
                        initialDate: endDate ?? startDate,
                        onStartDateSelected: { startDate in
                            onPeriodSelected(startDate, nil)
                        },
                        onEndDateSelected: { endDate in
                            onPeriodSelected(startDate, endDate)
                        },
                        onRemoveEndDate: nil,
                        onResetStartDate: nil
                    ))

                case .icon(let onIconSelected, let currentIcon):
                    AnyView(IconBottomSheetWrapper(
                        currentIcon: currentIcon,
                        onIconSelected: onIconSelected,
                        onClose: { manager.dismissSheet() }
                    ))

                case .custom(let config, let onOptionSelected):
                    AnyView(ConfigurableBottomSheet(
                        config: config,
                        onClose: { manager.dismissSheet() },
                        onOptionSelected: onOptionSelected
                    ))
                }
            }
        }
        .sheet(isPresented: $manager.isShowingSheet) {
            // Empty view - the actual sheet content is handled above
            EmptyView()
        }
    }
}

// MARK: - Icon Bottom Sheet Wrapper

struct IconBottomSheetWrapper: View {
    let currentIcon: String
    let onIconSelected: (String) -> Void
    let onClose: () -> Void
    
    @State private var selectedIcon: String
    
    init(currentIcon: String, onIconSelected: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.currentIcon = currentIcon
        self.onIconSelected = onIconSelected
        self.onClose = onClose
        self._selectedIcon = State(initialValue: currentIcon)
    }
    
    var body: some View {
        IconBottomSheet(
            selectedIcon: $selectedIcon,
            onClose: {
                onIconSelected(selectedIcon)
                onClose()
            }
        )
    }
}

// MARK: - Environment Key for Bottom Sheet Manager

struct BottomSheetManagerKey: EnvironmentKey {
    static let defaultValue = BottomSheetManager()
}

extension EnvironmentValues {
    var bottomSheetManager: BottomSheetManager {
        get { self[BottomSheetManagerKey.self] }
        set { self[BottomSheetManagerKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Access

extension View {
    func withBottomSheetManager() -> some View {
        self.environment(\.bottomSheetManager, BottomSheetManager())
    }
}

#Preview {
    VStack {
        Text("Bottom Sheet Manager Demo")
        
        Button("Show Color Sheet") {
            // This would be called from a view with access to the manager
        }
    }
    .withBottomSheetManager()
} 
