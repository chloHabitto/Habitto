import SwiftUI

// MARK: - Bottom Sheet Configuration Models

struct BottomSheetOption {
    let id: String
    let title: String
    let subtitle: String
    let value: Any
    let isSelected: Bool
    
    init(id: String, title: String, subtitle: String, value: Any, isSelected: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.isSelected = isSelected
    }
}

struct BottomSheetConfig {
    let title: String
    let description: String
    let options: [BottomSheetOption]
    let hasConfirmButton: Bool
    let confirmButtonTitle: String?
    
    init(
        title: String,
        description: String,
        options: [BottomSheetOption] = [],
        hasConfirmButton: Bool = false,
        confirmButtonTitle: String? = nil
    ) {
        self.title = title
        self.description = description
        self.options = options
        self.hasConfirmButton = hasConfirmButton
        self.confirmButtonTitle = confirmButtonTitle
    }
}

// MARK: - Predefined Configurations

extension BottomSheetConfig {
    static func scheduleConfig(selectedSchedule: String) -> BottomSheetConfig {
        let options = [
            BottomSheetOption(id: "everyday", title: "Everyday", subtitle: "Repeat every day", value: "Everyday", isSelected: selectedSchedule == "Everyday"),
            BottomSheetOption(id: "weekdays", title: "Weekdays", subtitle: "Monday to Friday", value: "Weekdays", isSelected: selectedSchedule == "Weekdays"),
            BottomSheetOption(id: "weekends", title: "Weekends", subtitle: "Saturday and Sunday", value: "Weekends", isSelected: selectedSchedule == "Weekends"),
            BottomSheetOption(id: "monday", title: "Monday", subtitle: "Every Monday", value: "Monday", isSelected: selectedSchedule == "Monday"),
            BottomSheetOption(id: "tuesday", title: "Tuesday", subtitle: "Every Tuesday", value: "Tuesday", isSelected: selectedSchedule == "Tuesday"),
            BottomSheetOption(id: "wednesday", title: "Wednesday", subtitle: "Every Wednesday", value: "Wednesday", isSelected: selectedSchedule == "Wednesday"),
            BottomSheetOption(id: "thursday", title: "Thursday", subtitle: "Every Thursday", value: "Thursday", isSelected: selectedSchedule == "Thursday"),
            BottomSheetOption(id: "friday", title: "Friday", subtitle: "Every Friday", value: "Friday", isSelected: selectedSchedule == "Friday"),
            BottomSheetOption(id: "saturday", title: "Saturday", subtitle: "Every Saturday", value: "Saturday", isSelected: selectedSchedule == "Saturday"),
            BottomSheetOption(id: "sunday", title: "Sunday", subtitle: "Every Sunday", value: "Sunday", isSelected: selectedSchedule == "Sunday")
        ]
        
        return BottomSheetConfig(
            title: "Schedule",
            description: "Set which day(s) you'd like to do this habit",
            options: options
        )
    }
    
    static func goalConfig(selectedGoal: String) -> BottomSheetConfig {
        let options = [
            BottomSheetOption(id: "1time", title: "1 time", subtitle: "Once per session", value: "1 time", isSelected: selectedGoal == "1 time"),
            BottomSheetOption(id: "2times", title: "2 times", subtitle: "Twice per session", value: "2 times", isSelected: selectedGoal == "2 times"),
            BottomSheetOption(id: "3times", title: "3 times", subtitle: "Three times per session", value: "3 times", isSelected: selectedGoal == "3 times"),
            BottomSheetOption(id: "5times", title: "5 times", subtitle: "Five times per session", value: "5 times", isSelected: selectedGoal == "5 times"),
            BottomSheetOption(id: "10times", title: "10 times", subtitle: "Ten times per session", value: "10 times", isSelected: selectedGoal == "10 times")
        ]
        
        return BottomSheetConfig(
            title: "Goal",
            description: "Set how many times you want to do this habit",
            options: options
        )
    }
}

// MARK: - Configurable Bottom Sheet

struct ConfigurableBottomSheet: View {
    let config: BottomSheetConfig
    let onClose: () -> Void
    let onOptionSelected: (BottomSheetOption) -> Void
    let onConfirm: (() -> Void)?
    
    init(
        config: BottomSheetConfig,
        onClose: @escaping () -> Void,
        onOptionSelected: @escaping (BottomSheetOption) -> Void,
        onConfirm: (() -> Void)? = nil
    ) {
        self.config = config
        self.onClose = onClose
        self.onOptionSelected = onOptionSelected
        self.onConfirm = onConfirm
    }
    
    var body: some View {
        BaseBottomSheet(
            title: config.title,
            description: config.description,
            onClose: onClose,
            confirmButton: onConfirm,
            confirmButtonTitle: config.confirmButtonTitle
        ) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(config.options, id: \.id) { option in
                        SelectionRow(
                            title: option.title,
                            subtitle: option.subtitle,
                            isSelected: option.isSelected,
                            onTap: {
                                onOptionSelected(option)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
}

#Preview {
    ConfigurableBottomSheet(
        config: .scheduleConfig(selectedSchedule: "Everyday"),
        onClose: {},
        onOptionSelected: { _ in }
    )
} 