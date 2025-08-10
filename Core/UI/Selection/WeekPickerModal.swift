import SwiftUI

// MARK: - Week Picker Modal
struct WeekPickerModal: View {
    @Binding var selectedWeekStartDate: Date
    @Binding var isPresented: Bool
    @State private var tempSelectedWeekStartDate: Date
    @State private var selectedDateRange: ClosedRange<Date>?
    
    init(selectedWeekStartDate: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedWeekStartDate = selectedWeekStartDate
        self._isPresented = isPresented
        self._tempSelectedWeekStartDate = State(initialValue: selectedWeekStartDate.wrappedValue)
        
        // Initialize selected range based on the current selected week (not always current week)
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedWeekStartDate.wrappedValue)?.start ?? selectedWeekStartDate.wrappedValue
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        self._selectedDateRange = State(initialValue: weekStart...weekEnd)
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Modal content
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("Select Week")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                    
                    Spacer()
                    
                    Button("Done") {
                        selectedWeekStartDate = tempSelectedWeekStartDate
                        isPresented = false
                    }
                    .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Custom Calendar
                CustomWeekSelectionCalendar(
                    selectedWeekStartDate: $tempSelectedWeekStartDate,
                    selectedDateRange: $selectedDateRange
                )
                .frame(height: 300)
                .padding(.horizontal, 20)
                // .background(Color.red)
                
                // Reset button - only show if week is different from current week
                if !isCurrentWeekSelected {
                    Button(action: {
                        resetToCurrentWeek()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.appBodyMedium)
                            Text("Reset to current week")
                                .font(.appBodyMedium)
                        }
                        .foregroundColor(.text02)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                }
                
                // Selected week display
                if let range = selectedDateRange {
                    Button(action: {
                        selectedWeekStartDate = tempSelectedWeekStartDate
                        isPresented = false
                    }) {
                        VStack(spacing: 8) {
                            Text("Selected Week")
                                .font(.appBodyMedium)
                                .foregroundColor(.surface)
                            
                            Text(weekRangeText(from: range))
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(.surface)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primary)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .background(.surface)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .frame(maxHeight: 480)
            .onAppear {
                // Update temporary state when modal appears to reflect current selection
                tempSelectedWeekStartDate = selectedWeekStartDate
                
                // Update selected range
                var calendar = Calendar.current
                calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedWeekStartDate)?.start ?? selectedWeekStartDate
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                selectedDateRange = weekStart...weekEnd
            }
        }
    }
    
    private func weekRangeText(from range: ClosedRange<Date>) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        
        let startText = formatter.string(from: range.lowerBound)
        let endText = formatter.string(from: range.upperBound)
        
        return "\(startText) - \(endText)"
    }
    
    // MARK: - Helper Properties and Functions
    
    private var isCurrentWeekSelected: Bool {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
        
        let today = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        return calendar.isDate(tempSelectedWeekStartDate, inSameDayAs: currentWeekStart)
    }
    
    private func resetToCurrentWeek() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
        
        let today = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let currentWeekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
        
        tempSelectedWeekStartDate = currentWeekStart
        selectedDateRange = currentWeekStart...currentWeekEnd
    }
}
