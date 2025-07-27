import SwiftUI

struct ScheduledHabitItem: View {
    let title: String
    let description: String
    let selectedColor: Color
    let icon: String // Can be emoji or asset name
    @Binding var isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // ColorMark
            Rectangle()
                .fill(selectedColor)
                .frame(width: 8)
                .frame(maxHeight: .infinity)
            
            // SelectedIcon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.surfaceContainer)
                    .frame(width: 30, height: 30)
                
                if icon.hasPrefix("Icon-") {
                    // Asset icon
                    Image(icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundColor(selectedColor)
                } else {
                    // Emoji or system icon
                    Text(icon)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
            
            // VStack with title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text02)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(description)
                    .font(.appBodyExtraSmall)
                    .foregroundColor(.text05)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            
            // CheckBox
            Button(action: {
                isCompleted.toggle()
            }) {
                Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.primaryDim)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .padding(.leading, 16)
            .padding(.trailing, 8)
        }
        .padding(.trailing, 4)
        .background(.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.outline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    VStack(spacing: 16) {
        ScheduledHabitItem(
            title: "Morning Exercise",
            description: "30 minutes of cardio",
            selectedColor: .green,
            icon: "🏃‍♂️",
            isCompleted: .constant(false)
        )
        
        ScheduledHabitItem(
            title: "Read Books",
            description: "Read 20 pages daily",
            selectedColor: .blue,
            icon: "📚",
            isCompleted: .constant(true)
        )
        
        ScheduledHabitItem(
            title: "Drink Water",
            description: "8 glasses of water per day",
            selectedColor: .orange,
            icon: "💧",
            isCompleted: .constant(false)
        )
    }
    .padding()
    .background(.surface2)
} 
