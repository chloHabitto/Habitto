import SwiftUI

struct IconBottomSheet: View {
    @Binding var selectedIcon: String
    let onClose: () -> Void
    
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    // Sample icons - you can expand this list
    private let icons = [
        "🏃‍♂️", "💪", "🧘‍♀️", "🏋️‍♂️", "🚴‍♂️", "🏊‍♂️",
        "📚", "✍️", "🎨", "🎵", "🎮", "🎯",
        "💧", "🍎", "🥗", "☕", "🛏️", "🧹",
        "💼", "📱", "💻", "📝", "📊", "🎪"
    ]
    
    // Emoji categories
    private let emojiCategories = [
        ("Smileys", ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜"]),
        ("Activities", ["⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🥅", "⛳", "🪁", "🏹", "🎣", "🤿", "🥊"]),
        ("Food", ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🥑", "🥦", "🥬", "🥒", "🌶️", "🫑", "🌽"]),
        ("Objects", ["💻", "📱", "📷", "🎥", "📺", "📻", "🔋", "💡", "🔍", "🔑", "🎁", "📦", "📝", "📊", "📈", "📉", "📋", "📌", "📍", "🔖", "🏷️", "📎", "📏", "📐"])
    ]
    
    var filteredEmojis: [(String, [String])] {
        if searchText.isEmpty {
            return emojiCategories
        } else {
            return emojiCategories.compactMap { category, emojis in
                let filtered = emojis.filter { $0.contains(searchText) }
                return filtered.isEmpty ? nil : (category, filtered)
            }
        }
    }
    
    var body: some View {
        BaseBottomSheet(
            title: "Select Icon",
            description: "Choose an icon for your habit",
            onClose: onClose
        ) {
            VStack(spacing: 0) {
                // Tab Menu
                TabMenu(
                    selectedTab: $selectedTab,
                    tabs: ["Emoji", "Simple"]
                )
                
                // Content based on selected tab
                if selectedTab == 0 {
                    // Emoji tab - iOS emoji keyboard
                    EmojiKeyboardView { emoji in
                        selectedIcon = emoji
                        onClose()
                    }
                } else {
                    // Simple tab - Custom icon grid
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                    onClose()
                                }) {
                                    Text(icon)
                                        .font(.appHeadlineMedium)
                                        .frame(width: 48, height: 48)
                                        .background(selectedIcon == icon ? .primary : .surface)
                                        .foregroundColor(selectedIcon == icon ? .onPrimary : .text01)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedIcon == icon ? .primary : .outline, lineWidth: 1.5)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .background(.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    IconBottomSheet(
        selectedIcon: .constant("🏃‍♂️"),
        onClose: {}
    )
} 
