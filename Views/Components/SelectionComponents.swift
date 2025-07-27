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
                        .font(.body)
                        .foregroundColor(.text01)
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.text04)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
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
            .font(.body)
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
        Group {
            Text(pill)
                .font(.body)
                .foregroundColor(.onPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "1C274C"))
                .clipShape(Capsule())
        }
    }
}

struct NumberStepper: View {
    let title: String
    let value: Binding<Int>
    let range: ClosedRange<Int>
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleView
            stepperContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private var titleView: some View {
        Text(title)
            .font(.title2)
            .foregroundColor(.text01)
    }
    
    @ViewBuilder
    private var stepperContent: some View {
        HStack {
            decrementButton
            Spacer()
            valueDisplay
            Spacer()
            incrementButton
        }
    }
    
    @ViewBuilder
    private var decrementButton: some View {
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
    }
    
    @ViewBuilder
    private var valueDisplay: some View {
        VStack(spacing: 4) {
            Text("\(value.wrappedValue)")
                .font(.title)
                .foregroundColor(.text01)
            Text(unit)
                .font(.body)
                .foregroundColor(.text04)
        }
    }
    
    @ViewBuilder
    private var incrementButton: some View {
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

struct TimePicker: View {
    let title: String
    let hours: Binding<Int>
    let minutes: Binding<Int>
    let seconds: Binding<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleView
            pickerContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private var titleView: some View {
        Text(title)
            .font(.title2)
            .foregroundColor(.text01)
    }
    
    @ViewBuilder
    private var pickerContent: some View {
        HStack(spacing: 16) {
            hoursPicker
            minutesPicker
            secondsPicker
        }
    }
    
    @ViewBuilder
    private var hoursPicker: some View {
        VStack(spacing: 8) {
            Text("Hours")
                .font(.body)
                .foregroundColor(.text04)
            
            Picker("Hours", selection: hours) {
                ForEach(0...23, id: \.self) { hour in
                    Text("\(hour)").tag(hour)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 120)
        }
    }
    
    @ViewBuilder
    private var minutesPicker: some View {
        VStack(spacing: 8) {
            Text("Minutes")
                .font(.body)
                .foregroundColor(.text04)
            
            Picker("Minutes", selection: minutes) {
                ForEach(0...59, id: \.self) { minute in
                    Text("\(minute)").tag(minute)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 120)
        }
    }
    
    @ViewBuilder
    private var secondsPicker: some View {
        VStack(spacing: 8) {
            Text("Seconds")
                .font(.body)
                .foregroundColor(.text04)
            
            Picker("Seconds", selection: seconds) {
                ForEach(0...59, id: \.self) { second in
                    Text("\(second)").tag(second)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 120)
        }
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
