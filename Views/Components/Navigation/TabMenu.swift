import SwiftUI

struct TabMenu: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 0) {
                        Text(tabs[index])
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(selectedTab == index ? .onPrimaryContainer : .text06)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        
                        Rectangle()
                            .fill(selectedTab == index ? .onPrimaryContainer : .primaryContainer)
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 0)
    }
}

#Preview {
    TabMenu(
        selectedTab: .constant(0),
        tabs: ["Emoji", "Simple"]
    )
} 
