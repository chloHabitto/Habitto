import SwiftUI

struct InsightCard: View {
    let type: InsightType
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundColor(type.color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(type.color.opacity(0.1))
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.appCaptionMedium)
                    .foregroundColor(.text05)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(type.color.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        InsightCard(
            type: .success,
            title: "Your best habit this week",
            description: "Morning Run (90% completion)"
        )
        
        InsightCard(
            type: .warning,
            title: "Your lowest-performing habit",
            description: "Read 30 min (42%)"
        )
        
        InsightCard(
            type: .info,
            title: "Overall Progress",
            description: "2 habits improving, 1 needs attention"
        )
        
        InsightCard(
            type: .tip,
            title: "Suggestion",
            description: "Try adjusting reminder time or lowering the goal to build consistency"
        )
    }
    .padding()
    .background(.surface2)
} 