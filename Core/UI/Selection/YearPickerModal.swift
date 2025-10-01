import SwiftUI

// MARK: - Year Picker Modal
struct YearPickerModal: View {
    @Binding var selectedYear: Int
    @Binding var isPresented: Bool
    @State private var tempSelectedYear: Int
    
    init(selectedYear: Binding<Int>, isPresented: Binding<Bool>) {
        self._selectedYear = selectedYear
        self._isPresented = isPresented
        self._tempSelectedYear = State(initialValue: selectedYear.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.text02)
                
                Spacer()
                
                Text("Select Year")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Button("Done") {
                    selectedYear = tempSelectedYear
                    isPresented = false
                }
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
            Spacer()
            
            // Year Picker
            YearPicker(selectedYear: $tempSelectedYear)
                .padding(.horizontal, 20)
                .environmentObject(HabitRepository.shared)
            
            Spacer()
                
            // Reset button - always reserve space for consistent height
                VStack {
                    if !isCurrentYearSelected {
                        Button(action: {
                            resetToCurrentYear()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.appBodyMedium)
                                Text("Reset to current year")
                                    .font(.appBodyMedium)
                            }
                            .foregroundColor(.text02)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    } else {
                        // Invisible spacer to maintain consistent height
                        Color.clear
                            .frame(height: 56) // Height of reset button + padding
                    }
                }
                
                // Selected year display
                Button(action: {
                    selectedYear = tempSelectedYear
                    isPresented = false
                }) {
                    VStack(spacing: 8) {
                        Text("Selected Year")
                            .font(.appBodyMedium)
                            .foregroundColor(.surface)
                        
                        Text(String(tempSelectedYear))
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.surface)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary)
                    .cornerRadius(20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
    }
    
    private var isCurrentYearSelected: Bool {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return tempSelectedYear == currentYear
    }
    
    private func resetToCurrentYear() {
        let calendar = Calendar.current
        tempSelectedYear = calendar.component(.year, from: Date())
    }
}

// MARK: - Year Picker
struct YearPicker: View {
    @Binding var selectedYear: Int
    @State private var currentYear: Int
    @EnvironmentObject var coreDataAdapter: HabitRepository
    
    init(selectedYear: Binding<Int>) {
        self._selectedYear = selectedYear
        self._currentYear = State(initialValue: selectedYear.wrappedValue)
    }
    
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
                
                Text(String(currentYear))
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
            
            // Year Grid - Show years in a grid format
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(availableYears, id: \.self) { year in
                    YearButton(
                        year: year,
                        isSelected: year == selectedYear,
                        onTap: {
                            selectedYear = year
                            currentYear = year // Update currentYear when a year is selected
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .onChange(of: selectedYear) { oldValue, newValue in
            // Update currentYear when selectedYear changes externally
            currentYear = newValue
        }
    }
    
    private var availableYears: [Int] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // Get the earliest year from user's habits (when they started using the app)
        let earliestYear = getUserEarliestYear()
        
        // Show years from earliest habit year to current year + 5
        return Array(earliestYear...(currentYear + 5))
    }
    
    private func getUserEarliestYear() -> Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // Default to current year if no habits exist
        guard !coreDataAdapter.habits.isEmpty else {
            return currentYear
        }
        
        // Find the earliest start date among all habits
        let earliestDate = coreDataAdapter.habits
            .compactMap { habit in
                habit.startDate
            }
            .min()
        
        if let earliestDate = earliestDate {
            let earliestYear = calendar.component(.year, from: earliestDate)
            // Ensure we don't go too far back (minimum 2020 for very old data)
            return max(earliestYear, 2020)
        }
        
        // Fallback to current year
        return currentYear
    }
    
    private func previousYear() {
        if let firstYear = availableYears.first, currentYear > firstYear {
            currentYear -= 1
        }
    }
    
    private func nextYear() {
        if let lastYear = availableYears.last, currentYear < lastYear {
            currentYear += 1
        }
    }
}

// MARK: - Year Button
struct YearButton: View {
    let year: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(String(year))
                .font(.appBodyMedium)
                .foregroundColor(isSelected ? .white : .text01)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? .primary : .surfaceContainer)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? .clear : .outline3, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    YearPickerModal(
        selectedYear: .constant(2024),
        isPresented: .constant(true)
    )
}
