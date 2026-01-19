//
//  MonthlyCompletionBarChart.swift
//  Habitto
//
//  Interactive HORIZONTAL bar chart showing monthly completion rates for the yearly view.
//  Features iOS 17 chartYSelection for drag interaction with selection details panel.
//

import Charts
import SwiftUI

// MARK: - MonthlyCompletionData

struct MonthlyCompletionData: Identifiable {
  let id = UUID()
  let month: String
  let monthNumber: Int
  let scheduledDays: Int
  let completedDays: Int

  var completionRate: Double {
    guard scheduledDays > 0 else { return 0 }
    return Double(completedDays) / Double(scheduledDays)
  }

  var percentage: Int {
    Int(completionRate * 100)
  }
}

// MARK: - MonthlyCompletionBarChartWrapper

struct MonthlyCompletionBarChartWrapper: View {
  let data: [MonthlyCompletionData]
  let accentColor: Color
  let title: String
  let subtitle: String

  var body: some View {
    if #available(iOS 17.0, *) {
      MonthlyCompletionBarChart_iOS17(
        data: data,
        accentColor: accentColor,
        title: title,
        subtitle: subtitle
      )
    } else {
      MonthlyCompletionBarChart_iOS16(
        data: data,
        accentColor: accentColor,
        title: title,
        subtitle: subtitle
      )
    }
  }
}

// MARK: - MonthlyCompletionBarChart (iOS 17+)

@available(iOS 17.0, *)
struct MonthlyCompletionBarChart_iOS17: View {
  let data: [MonthlyCompletionData]
  let accentColor: Color
  let title: String
  let subtitle: String

  @State private var selectedMonthName: String?

  private var selectedMonthData: MonthlyCompletionData? {
    guard let selectedMonthName else { return nil }
    return data.first { $0.month == selectedMonthName }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      headerSection
        .padding(.horizontal, 20)
        .padding(.top, 20)

      // Chart
      chartSection

      // Selected month details OR hint text
      if let selected = selectedMonthData {
        selectedMonthSection(for: selected)
      } else {
        // Hint text
        Text("Tap or drag on the chart to see details")
          .font(.appLabelSmall)
          .foregroundColor(.text05)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.bottom, 20)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(Color.surface01)
        .overlay(
          LinearGradient(
            stops: [
              Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
              Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
            ],
            startPoint: UnitPoint(x: 0.08, y: 0.09),
            endPoint: UnitPoint(x: 0.88, y: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 24))
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(Color("appOutline1Variant"), lineWidth: 2)
    )
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.appTitleMediumEmphasised)
        .foregroundColor(.text02)

      Text(subtitle)
        .font(.appBodySmall)
        .foregroundColor(.text04)
    }
  }

  // MARK: - Chart Section

  private var chartSection: some View {
    VStack(spacing: 6) {
      ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
        HStack(spacing: 8) {
          // Month label - LEFT of the bar
          Text(item.month)
            .font(.appLabelSmallEmphasised)
            .foregroundColor(selectedMonthName == item.month ? .text01 : .text04)
            .frame(width: 32, alignment: .trailing)

          // Bar with gradient
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              // Background track (subtle)
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.outline3.opacity(0.2))

              // Filled bar
              RoundedRectangle(cornerRadius: 4)
                .fill(
                  LinearGradient(
                    colors: [accentColor.opacity(0.7), accentColor],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .frame(width: max(4, geometry.size.width * item.completionRate))
                .opacity(selectedMonthName == nil || selectedMonthName == item.month ? 1.0 : 0.3)
            }
          }
          .frame(height: 20)
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
              selectedMonthName = selectedMonthName == item.month ? nil : item.month
            }
          }
        }
      }

      // X-axis labels
      HStack {
        Text("")
          .frame(width: 32) // Spacer to align with month labels

        HStack {
          Text("0%")
          Spacer()
          Text("25%")
          Spacer()
          Text("50%")
          Spacer()
          Text("75%")
          Spacer()
          Text("100%")
        }
        .font(.appLabelSmall)
        .foregroundColor(.text05)
      }
      .padding(.top, 8)
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Selected Month Section

  private func selectedMonthSection(for item: MonthlyCompletionData) -> some View {
    VStack(spacing: 0) {
      Divider()
        .background(Color.outline3)

      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(fullMonthName(for: item.month))
            .font(.appTitleSmallEmphasised)
            .foregroundColor(.text01)

          Text("Selected Month")
            .font(.appLabelSmall)
            .foregroundColor(.text04)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("\(item.percentage)%")
            .font(.appTitleMediumEmphasised)
            .foregroundColor(accentColor)

          Text("\(item.completedDays)/\(item.scheduledDays) days")
            .font(.appLabelSmall)
            .foregroundColor(.text04)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
    .transition(.opacity.combined(with: .move(edge: .bottom)))
    .animation(.easeInOut(duration: 0.2), value: selectedMonthName)
  }

  // MARK: - Helpers

  private func fullMonthName(for shortName: String) -> String {
    let shortToFull: [String: String] = [
      "Jan": "January", "Feb": "February", "Mar": "March",
      "Apr": "April", "May": "May", "Jun": "June",
      "Jul": "July", "Aug": "August", "Sep": "September",
      "Oct": "October", "Nov": "November", "Dec": "December"
    ]
    return shortToFull[shortName] ?? shortName
  }
}

// MARK: - MonthlyCompletionBarChart (iOS 16 Fallback)

struct MonthlyCompletionBarChart_iOS16: View {
  let data: [MonthlyCompletionData]
  let accentColor: Color
  let title: String
  let subtitle: String

  @State private var selectedIndex: Int?

  private var selectedMonthData: MonthlyCompletionData? {
    guard let selectedIndex, selectedIndex < data.count else { return nil }
    return data[selectedIndex]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text02)

        Text(subtitle)
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)

      // Chart - Manual horizontal bars
      VStack(spacing: 8) {
        ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
          HStack(spacing: 8) {
            // Month label
            Text(item.month)
              .font(.appLabelSmallEmphasised)
              .foregroundColor(selectedIndex == index ? .text01 : .text04)
              .frame(width: 32, alignment: .leading)

            // Bar
            GeometryReader { geometry in
              ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                  .fill(Color.outline3.opacity(0.3))
                  .frame(height: 16)

                // Filled bar
                RoundedRectangle(cornerRadius: 4)
                  .fill(
                    LinearGradient(
                      colors: [accentColor.opacity(0.7), accentColor],
                      startPoint: .leading,
                      endPoint: .trailing
                    )
                  )
                  .frame(width: max(4, geometry.size.width * item.completionRate), height: 16)
                  .opacity(selectedIndex == nil || selectedIndex == index ? 1.0 : 0.3)
              }
            }
            .frame(height: 16)
            .onTapGesture {
              withAnimation(.easeInOut(duration: 0.2)) {
                selectedIndex = selectedIndex == index ? nil : index
              }
            }

            // Percentage label
            Text("\(item.percentage)%")
              .font(.appLabelSmall)
              .foregroundColor(selectedIndex == index ? accentColor : .text05)
              .frame(width: 36, alignment: .trailing)
          }
        }
      }
      .padding(.horizontal, 20)

      // Selected month details OR hint text
      if let selected = selectedMonthData {
        VStack(spacing: 0) {
          Divider()
            .background(Color.outline3)

          HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
              Text(fullMonthName(for: selected.month))
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.text01)

              Text("Selected Month")
                .font(.appLabelSmall)
                .foregroundColor(.text04)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
              Text("\(selected.percentage)%")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(accentColor)

              Text("\(selected.completedDays)/\(selected.scheduledDays) days")
                .font(.appLabelSmall)
                .foregroundColor(.text04)
            }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
      } else {
        Text("Tap on a bar to see details")
          .font(.appLabelSmall)
          .foregroundColor(.text05)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.bottom, 20)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(Color.surface01)
        .overlay(
          LinearGradient(
            stops: [
              Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
              Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
            ],
            startPoint: UnitPoint(x: 0.08, y: 0.09),
            endPoint: UnitPoint(x: 0.88, y: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 24))
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(Color("appOutline1Variant"), lineWidth: 2)
    )
  }

  private func fullMonthName(for shortName: String) -> String {
    let shortToFull: [String: String] = [
      "Jan": "January", "Feb": "February", "Mar": "March",
      "Apr": "April", "May": "May", "Jun": "June",
      "Jul": "July", "Aug": "August", "Sep": "September",
      "Oct": "October", "Nov": "November", "Dec": "December"
    ]
    return shortToFull[shortName] ?? shortName
  }
}

// MARK: - Preview

#Preview {
  ScrollView {
    VStack(spacing: 20) {
      MonthlyCompletionBarChartWrapper(
        data: [
          MonthlyCompletionData(month: "Jan", monthNumber: 1, scheduledDays: 19, completedDays: 14),
          MonthlyCompletionData(month: "Feb", monthNumber: 2, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Mar", monthNumber: 3, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Apr", monthNumber: 4, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "May", monthNumber: 5, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Jun", monthNumber: 6, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Jul", monthNumber: 7, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Aug", monthNumber: 8, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Sep", monthNumber: 9, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Oct", monthNumber: 10, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Nov", monthNumber: 11, scheduledDays: 0, completedDays: 0),
          MonthlyCompletionData(month: "Dec", monthNumber: 12, scheduledDays: 0, completedDays: 0),
        ],
        accentColor: .primary,
        title: "Monthly Completions",
        subtitle: "All habits • 2026"
      )
    }
    .padding(.horizontal, 20)
  }
  .background(Color.surface2)
}
