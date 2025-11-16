import SwiftUI

/// Custom iOS-style emoji keyboard implementation!
struct EmojiKeyboardView: View {
  // MARK: Internal

  let onEmojiSelected: (String) -> Void

  var filteredEmojis: [String] {
    if searchText.isEmpty {
      return emojis[selectedCategory]
    } else {
      // Search across all emojis when searching
      let allEmojis = emojis.flatMap { $0 }
      return allEmojis.filter { $0.contains(searchText) }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Search bar
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.gray)
        TextField("Search emoji", text: $searchText)
          .focused($isSearchFocused)
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
          ForEach(0 ..< categories.count, id: \.self) { index in
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
        .background(.outline3)
        .padding(.top, 8)

      // Emoji grid
      ScrollView(showsIndicators: true) {
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8),
          spacing: 4)
        {
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
    .onAppear {
      // Ensure the search field is focused when the keyboard view appears
      // Using async to guarantee it happens after presentation animations
      DispatchQueue.main.async {
        isSearchFocused = true
      }
    }
  }

  // MARK: Private

  @State private var searchText = ""
  @State private var selectedCategory = 0
  @FocusState private var isSearchFocused: Bool

  private let categories = EmojiData.categories
  private let categoryNames = EmojiData.categoryNames
  private let emojis = EmojiData.emojis
}
