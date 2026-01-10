import SwiftUI

// MARK: - MonthPickerModal

struct MonthPickerModal: View {
  // MARK: Lifecycle

  init(selectedMonth: Binding<Date>, isPresented: Binding<Bool>) {
    self._selectedMonth = selectedMonth
    self._isPresented = isPresented
    self._tempSelectedMonth = State(initialValue: selectedMonth.wrappedValue)
  }

  // MARK: Internal

  @Binding var selectedMonth: Date
  @Binding var isPresented: Bool

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .foregroundColor(.text02)

        Spacer()

        Text("Select Month")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)

        Spacer()

        Button("Done") {
          selectedMonth = tempSelectedMonth
          isPresented = false
        }
        .foregroundColor(.primary)
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 20)

      // Month Picker
      MonthPicker(selectedMonth: $tempSelectedMonth)
        .frame(height: 300)
        .padding(.horizontal, 20)

      // Reset button - only show if month is different from current month
      if !isCurrentMonthSelected {
        Button(action: {
          resetToCurrentMonth()
        }) {
          HStack {
            Image(systemName: "arrow.clockwise")
              .font(.appBodyMedium)
            Text("Reset to current month")
              .font(.appBodyMedium)
          }
          .foregroundColor(.text02)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 20)
      }

      Spacer()

      // Selected month display
      Button(action: {
        selectedMonth = tempSelectedMonth
        isPresented = false
      }) {
        VStack(spacing: 8) {
          Text("Selected Month")
            .font(.appBodyMedium)
            .foregroundColor(.appOnPrimary)

          Text(monthText(from: tempSelectedMonth))
            .font(.appTitleMediumEmphasised)
            .foregroundColor(.appOnPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.primary)
        .cornerRadius(32)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
  }

  // MARK: Private

  @State private var tempSelectedMonth: Date

  private var isCurrentMonthSelected: Bool {
    let calendar = Calendar.current
    let currentMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
    let selectedMonth = calendar.dateInterval(of: .month, for: tempSelectedMonth)?
      .start ?? tempSelectedMonth
    return calendar.isDate(currentMonth, inSameDayAs: selectedMonth)
  }

  private func resetToCurrentMonth() {
    let calendar = Calendar.current
    tempSelectedMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
  }

  private func monthText(from date: Date) -> String {
    AppDateFormatter.shared.formatMonthYear(date)
  }
}

// MARK: - MonthPicker

struct MonthPicker: View {
  // MARK: Lifecycle

  init(selectedMonth: Binding<Date>) {
    self._selectedMonth = selectedMonth
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: selectedMonth.wrappedValue)
    self._currentYear = State(initialValue: components.year ?? calendar.component(
      .year,
      from: Date()))
    self._currentMonth = State(initialValue: components.month ?? calendar.component(
      .month,
      from: Date()))
  }

  // MARK: Internal

  @Binding var selectedMonth: Date

  var body: some View {
    VStack(spacing: 16) {
      // Year Navigation
      HStack {
        Button(action: previousYear) {
          Image(systemName: "chevron.left")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
        }

        Spacer()

        Text("\(yearName(from: currentYear))")
          .font(.appTitleMedium)
          .foregroundColor(.text01)

        Spacer()

        Button(action: nextYear) {
          Image(systemName: "chevron.right")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
        }
      }
      .padding(.horizontal, 20)

      // Month Grid
      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
        ForEach(1 ... 12, id: \.self) { month in
          MonthButton(
            month: month,
            year: currentYear,
            isSelected: isMonthSelected(month: month, year: currentYear),
            onTap: {
              selectMonth(month: month, year: currentYear)
            })
        }
      }
      .padding(.horizontal, 20)
    }
  }

  // MARK: Private

  @State private var currentYear: Int
  @State private var currentMonth: Int

  private func previousYear() {
    currentYear -= 1
    updateSelectedMonth()
  }

  private func nextYear() {
    currentYear += 1
    updateSelectedMonth()
  }

  private func selectMonth(month: Int, year: Int) {
    currentMonth = month
    currentYear = year
    updateSelectedMonth()
  }

  private func updateSelectedMonth() {
    let calendar = Calendar.current
    var components = DateComponents()
    components.year = currentYear
    components.month = currentMonth
    components.day = 1

    if let newDate = calendar.date(from: components) {
      selectedMonth = newDate
    }
  }

  private func isMonthSelected(month: Int, year: Int) -> Bool {
    let calendar = Calendar.current
    let selectedComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
    return selectedComponents.year == year && selectedComponents.month == month
  }

  private func yearName(from year: Int) -> String {
    "\(year)"
  }
}

// MARK: - MonthButton

struct MonthButton: View {
  // MARK: Internal

  let month: Int
  let year: Int
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      Text(monthName)
        .font(.appBodyMedium)
        .foregroundColor(isSelected ? .appOnPrimary : .text01)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(isSelected ? .primary : .surfaceContainer)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? .clear : .outline3, lineWidth: 1))
    }
    .buttonStyle(PlainButtonStyle())
  }

  // MARK: Private

  private var monthName: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"
    let calendar = Calendar.current
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = 1
    if let date = calendar.date(from: components) {
      return formatter.string(from: date)
    }
    return "Unknown"
  }
}

#Preview {
  MonthPickerModal(
    selectedMonth: .constant(Date()),
    isPresented: .constant(true))
}
