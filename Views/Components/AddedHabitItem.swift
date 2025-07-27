import SwiftUI

struct AddedHabitItem: View {
    let title: String
    let description: String
    let selectedColor: Color
    let icon: String // Can be emoji or asset name
    let schedule: String
    let goal: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
            
            // VStack with title, description, and bottom row
            VStack(spacing: 8) {
                // Top row: Text container and more button
                HStack(spacing: 4) {
                    // Text container
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
                    .padding(.top, 8)
                    
                    // More button
                    Button(action: {
                        // TODO: Add more button action
                    }) {
                        Image("Icon-more_vert")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.primaryDim)
                            .contentShape(Rectangle())
                    }
                    .frame(width: 40, height: 40)
                }
                
                                        // Bottom row: Schedule and goal
                        HStack(spacing: 4) {
                            // Schedule
                            HStack(spacing: 4) {
                                Image("Icon-calendarMarked-filled")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.text05)
                                
                                Text(schedule)
                                    .font(.appBodyExtraSmall)
                                    .foregroundColor(.text05)
                            }
                            
                            // Dot separator
                            Circle()
                                .fill(.text06)
                                .frame(width: 3, height: 3)
                                .frame(width: 16, height: 16)
                            
                            // Goal
                            HStack(spacing: 4) {
                                Image("Icon-flag-filled")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.text05)
                                
                                Text(goal)
                                    .font(.appBodyExtraSmall)
                                    .foregroundColor(.text05)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
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
        AddedHabitItem(
            title: "Morning Exercise",
            description: "Start the day with a quick workout",
            selectedColor: .blue,
            icon: "🏃‍♂️",
            schedule: "Daily",
            goal: "30 minutes"
        )
        
        AddedHabitItem(
            title: "Read Books",
            description: "Read at least one chapter every day",
            selectedColor: .green,
            icon: "📚",
            schedule: "Weekdays",
            goal: "1 chapter"
        )
    }
    .padding()
    .background(.surface)
} 
