import SwiftUI

// MARK: - Selection Components

struct SelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appBodyLarge)
                        .foregroundColor(.text01)
                    Text(subtitle)
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.appLabelMedium)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .primary : .outline, lineWidth: 1.5)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PillSelectionRow: View {
    let title: String
    let pills: [String]
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            pillContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var pillContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleView
            pillGridView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? .primary : .outline, lineWidth: 1.5)
        )
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var titleView: some View {
        Text(title)
            .font(.appBodyLarge)
            .foregroundColor(.text01)
    }
    
    @ViewBuilder
    private var pillGridView: some View {
        if !pills.isEmpty {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(pills, id: \.self) { pill in
                    pillView(for: pill)
                }
            }
        }
    }
    
    @ViewBuilder
    private func pillView(for pill: String) -> some View {
        Text(pill)
            .font(.appBodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.11, green: 0.15, blue: 0.30)) // 1C274C in RGB
            .clipShape(Capsule())
    }
}

struct NumberStepper: View {
    let title: String
    let value: Binding<Int>
    let range: ClosedRange<Int>
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            HStack {
                Button(action: {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                }) {
                    Image("Icon-minus")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(value.wrappedValue > range.lowerBound ? .text01 : .text05)
                }
                .frame(width: 48, height: 48)
                .background(.secondaryContainer)
                .cornerRadius(8)
                .disabled(value.wrappedValue <= range.lowerBound)
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("\(value.wrappedValue)")
                        .font(.appHeadlineMediumEmphasised)
                        .foregroundColor(.text01)
                    Text(unit)
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                }
                
                Spacer()
                
                Button(action: {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                }) {
                    Image("Icon-plus")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(value.wrappedValue < range.upperBound ? .text01 : .text05)
                }
                .frame(width: 48, height: 48)
                .background(.secondaryContainer)
                .cornerRadius(8)
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

struct TimePicker: View {
    let title: String
    let hours: Binding<Int>
    let minutes: Binding<Int>
    let seconds: Binding<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            HStack(spacing: 16) {
                // Hours
                VStack(spacing: 8) {
                    Text("Hours")
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                    
                    Picker("Hours", selection: hours) {
                        ForEach(0...23, id: \.self) { hour in
                            Text("\(hour)").tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                }
                .frame(maxWidth: .infinity)
                
                // Minutes
                VStack(spacing: 8) {
                    Text("Minutes")
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                    
                    Picker("Minutes", selection: minutes) {
                        ForEach(0...59, id: \.self) { minute in
                            Text("\(minute)").tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                }
                .frame(maxWidth: .infinity)
                
                // Seconds
                VStack(spacing: 8) {
                    Text("Seconds")
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                    
                    Picker("Seconds", selection: seconds) {
                        ForEach(0...59, id: \.self) { second in
                            Text("\(second)").tag(second)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        SelectionRow(
            title: "Everyday",
            subtitle: "Repeat every day",
            isSelected: true,
            onTap: {}
        )
        
        PillSelectionRow(
            title: "Custom Days",
            pills: ["Monday", "Wednesday", "Friday"],
            isSelected: false,
            onTap: {}
        )
        
        NumberStepper(
            title: "Times per day",
            value: .constant(3),
            range: 1...10,
            unit: "times"
        )
    }
    .padding()
} 
