import SwiftUI

// MARK: - Reusable Selection Row Components
// These components eliminate code duplication across Create Habit step views

// MARK: - Bottom Sheet Selection Row (for bottom sheet options)
struct BottomSheetSelectionRow: View {
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
                    .stroke(isSelected ? .primary : .outline3, lineWidth: 1.5)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Create Habit Selection Row (for create habit flow)
struct SelectionRow: View {
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Spacer()
                Text(value)
                    .font(.appBodyLarge)
                    .foregroundColor(.text04)
                Image(systemName: "chevron.right")
                    .font(.appLabelMedium)
                    .foregroundColor(.primaryDim)
            }
        }
        .selectionRowStyle()
    }
}



struct SelectionRowWithVisual: View {
    let title: String
    let value: String
    let action: () -> Void
    let visualType: VisualType
    
    enum VisualType {
        case color(Color)
        case icon(String, Color)
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Spacer()
                HStack(spacing: 8) {
                    visualView
                    Text(value)
                        .font(.appBodyLarge)
                        .foregroundColor(.text04)
                }
                Image(systemName: "chevron.right")
                    .font(.appLabelMedium)
                    .foregroundColor(.primaryDim)
            }
        }
        .selectionRowStyle()
    }
    
    @ViewBuilder
    private var visualView: some View {
        switch visualType {
        case .color(let color):
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 24, height: 24)
        case .icon(let icon, let color):
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                if icon.hasPrefix("Icon-") {
                    // Asset icon
                    Image(icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundColor(color)
                } else if icon == "None" {
                    // No icon selected - show colored rounded rectangle
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 14, height: 14)
                } else {
                    // Emoji or system icon
                    Text(icon)
                        .font(.system(size: 14))
                }
            }
        }
    }
}

// MARK: - Convenience Initializers for Common Visual Elements
extension SelectionRowWithVisual {
    init(
        title: String,
        color: Color,
        value: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.action = action
        self.visualType = .color(color)
    }
    
    init(
        title: String,
        icon: String,
        color: Color,
        value: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.action = action
        self.visualType = .icon(icon, color)
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
                .stroke(isSelected ? .primary : .outline3, lineWidth: 1.5)
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
            value: "Repeat every day",
            action: {}
        )
        
        SelectionRowWithVisual(
            title: "Custom Days",
            color: .blue,
            value: "Monday, Wednesday, Friday",
            action: {}
        )
        
        SelectionRowWithVisual(
            title: "Custom Days",
            icon: "Icon-calendar",
            color: .purple,
            value: "Monday, Wednesday, Friday",
            action: {}
        )
        
        SelectionRowWithVisual(
            title: "Custom Days",
            icon: "None",
            color: .orange,
            value: "Monday, Wednesday, Friday",
            action: {}
        )
        
        SelectionRowWithVisual(
            title: "Custom Days",
            icon: "🌟",
            color: .green,
            value: "Monday, Wednesday, Friday",
            action: {}
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
