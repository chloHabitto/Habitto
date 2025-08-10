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
                
                // Year Picker
                YearPicker(selectedYear: $tempSelectedYear)
                    .frame(height: 300)
                    .padding(.horizontal, 20)
                
                // Reset button - only show if year is different from current year
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
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(.surface)
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var availableYears: [Int] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        // Show years from 2020 to current year + 5
        return Array(2020...(currentYear + 5))
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
                        .stroke(isSelected ? .clear : .outline, lineWidth: 1)
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
