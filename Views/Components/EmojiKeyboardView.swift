import SwiftUI

// Custom iOS-style emoji keyboard implementation!
struct EmojiKeyboardView: View {
    let onEmojiSelected: (String) -> Void
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory = 0
    
    // Performance optimization: Pagination for large emoji sets
    @State private var currentPage = 0
    private let itemsPerPage = 100
    
    private let categories = EmojiData.categories
    private let categoryNames = EmojiData.categoryNames
    private let emojis = EmojiData.emojis
    
    // Performance optimization: Cache filtered results
    @State private var cachedFilteredEmojis: [String] = []
    @State private var lastFilterState: (Int, String) = (0, "")
    
    var filteredEmojis: [String] {
        let currentState = (selectedCategory, debouncedSearchText)
        
        // Only recalculate if filter state changed
        if lastFilterState != currentState {
            let categoryEmojis = emojis[selectedCategory]
            let filtered = debouncedSearchText.isEmpty ? categoryEmojis : categoryEmojis.filter { $0.contains(debouncedSearchText) }
            
            // Performance optimization: Return paginated results for large sets
            let startIndex = currentPage * itemsPerPage
            let endIndex = min(startIndex + itemsPerPage, filtered.count)
            let newCachedEmojis = Array(filtered[startIndex..<endIndex])
            
            // Don't modify state in computed property - just return the calculated result
            return newCachedEmojis
        }
        
        return cachedFilteredEmojis
    }
    
    var hasMoreEmojis: Bool {
        let categoryEmojis = emojis[selectedCategory]
        let filtered = debouncedSearchText.isEmpty ? categoryEmojis : categoryEmojis.filter { $0.contains(debouncedSearchText) }
        return (currentPage + 1) * itemsPerPage < filtered.count
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
                            currentPage = 0 // Reset pagination when category changes
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
            
            // Emoji grid with pagination
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 4) {
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
                    
                    // Load more button for pagination
                    if hasMoreEmojis {
                        Button(action: {
                            currentPage += 1
                        }) {
                            Text("Load More")
                                .font(.appBodyMedium)
                                .foregroundColor(.primary)
                                .padding(.vertical, 8)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .onChange(of: searchText) { _, newValue in
                // Use a more appropriate debouncing approach
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    await MainActor.run {
                        if searchText == newValue { // Only update if search text hasn't changed
                            debouncedSearchText = newValue
                            currentPage = 0 // Reset pagination when search changes
                        }
                    }
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                // Update cached state when category changes
                let currentState = (selectedCategory, debouncedSearchText)
                let categoryEmojis = emojis[selectedCategory]
                let filtered = debouncedSearchText.isEmpty ? categoryEmojis : categoryEmojis.filter { $0.contains(debouncedSearchText) }
                let startIndex = currentPage * itemsPerPage
                let endIndex = min(startIndex + itemsPerPage, filtered.count)
                cachedFilteredEmojis = Array(filtered[startIndex..<endIndex])
                lastFilterState = currentState
            }
            .onChange(of: debouncedSearchText) { _, _ in
                // Update cached state when debounced search text changes
                let currentState = (selectedCategory, debouncedSearchText)
                let categoryEmojis = emojis[selectedCategory]
                let filtered = debouncedSearchText.isEmpty ? categoryEmojis : categoryEmojis.filter { $0.contains(debouncedSearchText) }
                let startIndex = currentPage * itemsPerPage
                let endIndex = min(startIndex + itemsPerPage, filtered.count)
                cachedFilteredEmojis = Array(filtered[startIndex..<endIndex])
                lastFilterState = currentState
            }
        }
    }
} 
