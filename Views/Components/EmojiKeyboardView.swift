import SwiftUI

// Custom iOS-style emoji keyboard implementation!
struct EmojiKeyboardView: View {
    let onEmojiSelected: (String) -> Void
    @State private var searchText = ""
    @State private var selectedCategory = 0
    
    private let categories = EmojiData.categories
    private let categoryNames = EmojiData.categoryNames
    private let emojis = EmojiData.emojis
    
    var filteredEmojis: [String] {
        let categoryEmojis = emojis[selectedCategory]
        return searchText.isEmpty ? categoryEmojis : categoryEmojis.filter { $0.contains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search emoji", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<categories.count, id: \.self) { index in
                        Button(action: {
                            selectedCategory = index
                        }) {
                            Text(categories[index])
                                .font(.appHeadlineSmall)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCategory == index ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            
            // Bottom stroke to separate category tabs from emoji grid
            Divider()
                .background(.outline)
                .padding(.top, 8)
            
            // Emoji grid
            ScrollView(showsIndicators: true) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(filteredEmojis, id: \.self) { emoji in
                        Button(action: {
                            onEmojiSelected(emoji)
                        }) {
                            Text(emoji)
                                .font(.appHeadlineMedium)
                                .frame(width: 44, height: 44)
                                .background(Color.clear)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
} 
