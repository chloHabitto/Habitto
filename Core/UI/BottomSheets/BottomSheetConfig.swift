import SwiftUI

// MARK: - BottomSheetOption

struct BottomSheetOption {
  // MARK: Lifecycle

  init(id: String, title: String, subtitle: String, value: Any, isSelected: Bool = false) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.value = value
    self.isSelected = isSelected
  }

  // MARK: Internal

  let id: String
  let title: String
  let subtitle: String
  let value: Any
  let isSelected: Bool
}

// MARK: - BottomSheetConfig

struct BottomSheetConfig {
  // MARK: Lifecycle

  init(
    title: String,
    description: String,
    options: [BottomSheetOption] = [],
    hasConfirmButton: Bool = false,
    confirmButtonTitle: String? = nil)
  {
    self.title = title
    self.description = description
    self.options = options
    self.hasConfirmButton = hasConfirmButton
    self.confirmButtonTitle = confirmButtonTitle
  }

  // MARK: Internal

  let title: String
  let description: String
  let options: [BottomSheetOption]
  let hasConfirmButton: Bool
  let confirmButtonTitle: String?
}

// MARK: - Predefined Configurations

extension BottomSheetConfig {
  /// Schedule preset sheet. `value` strings stay English identifiers (persisted / compared in scheduling logic).
  @MainActor
  static func scheduleConfig(selectedSchedule: String) -> BottomSheetConfig {
    let options = [
      BottomSheetOption(
        id: "everyday",
        title: "shared.schedule.everyday".localized,
        subtitle: "shared.schedule.everydaySubtitle".localized,
        value: "Everyday",
        isSelected: selectedSchedule == "Everyday"),
      BottomSheetOption(
        id: "weekdays",
        title: "shared.schedule.weekdays".localized,
        subtitle: "shared.schedule.weekdaysSubtitle".localized,
        value: "Weekdays",
        isSelected: selectedSchedule == "Weekdays"),
      BottomSheetOption(
        id: "weekends",
        title: "shared.schedule.weekends".localized,
        subtitle: "shared.schedule.weekendsSubtitle".localized,
        value: "Weekends",
        isSelected: selectedSchedule == "Weekends"),
      BottomSheetOption(
        id: "monday",
        title: "home.weekday.monday".localized,
        subtitle: "shared.schedule.everyMonday".localized,
        value: "Monday",
        isSelected: selectedSchedule == "Monday"),
      BottomSheetOption(
        id: "tuesday",
        title: "home.weekday.tuesday".localized,
        subtitle: "shared.schedule.everyTuesday".localized,
        value: "Tuesday",
        isSelected: selectedSchedule == "Tuesday"),
      BottomSheetOption(
        id: "wednesday",
        title: "home.weekday.wednesday".localized,
        subtitle: "shared.schedule.everyWednesday".localized,
        value: "Wednesday",
        isSelected: selectedSchedule == "Wednesday"),
      BottomSheetOption(
        id: "thursday",
        title: "home.weekday.thursday".localized,
        subtitle: "shared.schedule.everyThursday".localized,
        value: "Thursday",
        isSelected: selectedSchedule == "Thursday"),
      BottomSheetOption(
        id: "friday",
        title: "home.weekday.friday".localized,
        subtitle: "shared.schedule.everyFriday".localized,
        value: "Friday",
        isSelected: selectedSchedule == "Friday"),
      BottomSheetOption(
        id: "saturday",
        title: "home.weekday.saturday".localized,
        subtitle: "shared.schedule.everySaturday".localized,
        value: "Saturday",
        isSelected: selectedSchedule == "Saturday"),
      BottomSheetOption(
        id: "sunday",
        title: "home.weekday.sunday".localized,
        subtitle: "shared.schedule.everySunday".localized,
        value: "Sunday",
        isSelected: selectedSchedule == "Sunday")
    ]

    return BottomSheetConfig(
      title: "create.schedule.title".localized,
      description: "create.schedule.description".localized,
      options: options)
  }

  /// Goal amount presets. `value` strings stay English identifiers for selection matching.
  @MainActor
  static func goalConfig(selectedGoal: String) -> BottomSheetConfig {
    let options = [
      BottomSheetOption(
        id: "1time",
        title: "shared.goal.oneTime".localized,
        subtitle: "shared.goal.oneTimeSubtitle".localized,
        value: "1 time",
        isSelected: selectedGoal == "1 time"),
      BottomSheetOption(
        id: "2times",
        title: "shared.goal.twoTimes".localized,
        subtitle: "shared.goal.twoTimesSubtitle".localized,
        value: "2 times",
        isSelected: selectedGoal == "2 times"),
      BottomSheetOption(
        id: "3times",
        title: "shared.goal.threeTimes".localized,
        subtitle: "shared.goal.threeTimesSubtitle".localized,
        value: "3 times",
        isSelected: selectedGoal == "3 times"),
      BottomSheetOption(
        id: "5times",
        title: "shared.goal.fiveTimes".localized,
        subtitle: "shared.goal.fiveTimesSubtitle".localized,
        value: "5 times",
        isSelected: selectedGoal == "5 times"),
      BottomSheetOption(
        id: "10times",
        title: "shared.goal.tenTimes".localized,
        subtitle: "shared.goal.tenTimesSubtitle".localized,
        value: "10 times",
        isSelected: selectedGoal == "10 times")
    ]

    return BottomSheetConfig(
      title: "shared.goal.title".localized,
      description: "shared.goal.description".localized,
      options: options)
  }
}

// MARK: - ConfigurableBottomSheet

struct ConfigurableBottomSheet: View {
  // MARK: Lifecycle

  init(
    config: BottomSheetConfig,
    onClose: @escaping () -> Void,
    onOptionSelected: @escaping (BottomSheetOption) -> Void,
    onConfirm: (() -> Void)? = nil)
  {
    self.config = config
    self.onClose = onClose
    self.onOptionSelected = onOptionSelected
    self.onConfirm = onConfirm
  }

  // MARK: Internal

  let config: BottomSheetConfig
  let onClose: () -> Void
  let onOptionSelected: (BottomSheetOption) -> Void
  let onConfirm: (() -> Void)?

  var body: some View {
    BaseBottomSheet(
      title: config.title,
      description: config.description,
      onClose: onClose,
      useGlassCloseButton: true,
      confirmButton: onConfirm,
      confirmButtonTitle: config.confirmButtonTitle)
    {
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(config.options, id: \.id) { option in
            BottomSheetSelectionRow(
              title: option.title,
              subtitle: option.subtitle,
              isSelected: option.isSelected,
              onTap: {
                onOptionSelected(option)
              })
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
    onClose: { },
    onOptionSelected: { _ in })
}
