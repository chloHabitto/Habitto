import SwiftUI
import Charts

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
    VStack(spacing: 0) {
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
}

// MARK: - MonthlyCompletionBarChart (iOS 17+)

@available(iOS 17.0, *)
struct MonthlyCompletionBarChart_iOS17: View {
  let data: [MonthlyCompletionData]
  let accentColor: Color
  let title: String
  let subtitle: String
  
  @State private var selectedMonth: Int?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        
        Text(subtitle)
          .font(.appBodySmall)
          .foregroundColor(.text02)
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      
      // Chart
      Chart {
        ForEach(data) { monthData in
          BarMark(
            x: .value("Completion", monthData.completionRate),
            y: .value("Month", monthData.month)
          )
          .foregroundStyle(
            selectedMonth == nil || selectedMonth == monthData.monthNumber
              ? accentColor.gradient
              : accentColor.opacity(0.3).gradient
          )
          .cornerRadius(4)
        }
      }
      .chartYSelection(value: $selectedMonth)
      .chartXAxis {
        AxisMarks(position: .bottom, values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
          if let doubleValue = value.as(Double.self) {
            AxisValueLabel {
              Text("\(Int(doubleValue * 100))%")
                .font(.appLabelSmall)
                .foregroundColor(.text03)
            }
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
              .foregroundStyle(Color.outline3.opacity(0.3))
          }
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          if let stringValue = value.as(String.self) {
            AxisValueLabel {
              Text(stringValue)
                .font(.appLabelSmall)
                .foregroundColor(.text02)
            }
          }
        }
      }
      .chartXScale(domain: 0...1)
      .frame(height: 340)
      .padding(.horizontal, 20)
      
      // Selected month details
      if let selected = selectedMonth,
         let monthData = data.first(where: { $0.monthNumber == selected }) {
        VStack(spacing: 8) {
          Divider()
            .background(Color.outline3)
          
          HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
              Text(monthData.month)
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.text01)
              Text("Selected Month")
                .font(.appBodySmall)
                .foregroundColor(.text02)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
              Text("\(monthData.percentage)%")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(accentColor)
              Text("\(monthData.completedDays)/\(monthData.scheduledDays) days")
                .font(.appBodySmall)
                .foregroundColor(.text02)
            }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: selectedMonth)
      }
      
      Spacer()
        .frame(height: 20)
    }
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(.appSurface01)
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
}

// MARK: - MonthlyCompletionBarChart (iOS 16 Fallback)

struct MonthlyCompletionBarChart_iOS16: View {
  let data: [MonthlyCompletionData]
  let accentColor: Color
  let title: String
  let subtitle: String
  
  @State private var selectedMonth: Int?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        
        Text(subtitle)
          .font(.appBodySmall)
          .foregroundColor(.text02)
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      
      // Chart
      Chart {
        ForEach(data) { monthData in
          BarMark(
            x: .value("Completion", monthData.completionRate),
            y: .value("Month", monthData.month)
          )
          .foregroundStyle(
            selectedMonth == nil || selectedMonth == monthData.monthNumber
              ? accentColor.gradient
              : accentColor.opacity(0.3).gradient
          )
          .cornerRadius(4)
        }
      }
      .chartXAxis {
        AxisMarks(position: .bottom, values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
          if let doubleValue = value.as(Double.self) {
            AxisValueLabel {
              Text("\(Int(doubleValue * 100))%")
                .font(.appLabelSmall)
                .foregroundColor(.text03)
            }
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
              .foregroundStyle(Color.outline3.opacity(0.3))
          }
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          if let stringValue = value.as(String.self) {
            AxisValueLabel {
              Text(stringValue)
                .font(.appLabelSmall)
                .foregroundColor(.text02)
            }
          }
        }
      }
      .chartXScale(domain: 0...1)
      .frame(height: 340)
      .padding(.horizontal, 20)
      .onTapGesture { location in
        // Simple tap selection for iOS 16 (horizontal bars)
        let chartHeight: CGFloat = 340
        let barHeight = chartHeight / CGFloat(data.count)
        let tappedIndex = Int(location.y / barHeight)
        
        if tappedIndex >= 0 && tappedIndex < data.count {
          let tappedMonth = data[tappedIndex].monthNumber
          if selectedMonth == tappedMonth {
            selectedMonth = nil
          } else {
            selectedMonth = tappedMonth
          }
        }
      }
      
      // Selected month details
      if let selected = selectedMonth,
         let monthData = data.first(where: { $0.monthNumber == selected }) {
        VStack(spacing: 8) {
          Divider()
            .background(Color.outline3)
          
          HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
              Text(monthData.month)
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.text01)
              Text("Selected Month")
                .font(.appBodySmall)
                .foregroundColor(.text02)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
              Text("\(monthData.percentage)%")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(accentColor)
              Text("\(monthData.completedDays)/\(monthData.scheduledDays) days")
                .font(.appBodySmall)
                .foregroundColor(.text02)
            }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: selectedMonth)
      }
      
      Spacer()
        .frame(height: 20)
    }
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(.appSurface01)
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
}

// MARK: - Preview

#Preview {
  let sampleData = [
    MonthlyCompletionData(month: "Jan", monthNumber: 1, scheduledDays: 31, completedDays: 28),
    MonthlyCompletionData(month: "Feb", monthNumber: 2, scheduledDays: 28, completedDays: 25),
    MonthlyCompletionData(month: "Mar", monthNumber: 3, scheduledDays: 31, completedDays: 30),
    MonthlyCompletionData(month: "Apr", monthNumber: 4, scheduledDays: 30, completedDays: 22),
    MonthlyCompletionData(month: "May", monthNumber: 5, scheduledDays: 31, completedDays: 29),
    MonthlyCompletionData(month: "Jun", monthNumber: 6, scheduledDays: 30, completedDays: 28),
  ]
  
  return ScrollView {
    MonthlyCompletionBarChartWrapper(
      data: sampleData,
      accentColor: .blue,
      title: "Monthly Completions",
      subtitle: "All habits • 2026"
    )
    .padding()
  }
}
