# Architecture Investigation Answers

## 1. Current Header Structure in ProgressTabView

**Location:** `Views/Tabs/ProgressTabView.swift`, lines 185-233

**Exact UI Elements:**
The `headerContent` computed property contains a `VStack(spacing: 0)` with two main elements:

1. **Habit Selector (First Filter)**
   - `HStack` containing a `Button`
   - Button contains:
     - `Text` with `.appTitleMediumEmphasised` font (16pt, semibold)
     - `Image("Icon-arrowDropDown_Filled")` with 24x24 frame
   - Padding: `.horizontal(20)`, `.top(12)`
   - No explicit height constraint
   - No `.fixedSize()` modifier

2. **Period Selection Tabs (Second Filter)**
   - `UnifiedTabBarView` with 4 tabs (Daily, Weekly, Monthly, Yearly)
   - Style: `.underline`
   - Padding: `.top(16)`, `.bottom(0)`
   - Tab buttons have `.padding(.horizontal, 16)` and `.padding(.vertical, 12)`
   - Includes a 4px underline stroke for selected tabs
   - Background color: `.surface1`

**Approximate Heights:**
- Habit selector row: ~12pt (top padding) + ~24pt (content height) = **~36pt**
- Tab bar: ~16pt (top padding) + ~24pt (vertical padding: 12*2) + ~18pt (text height) = **~54pt** (underline is inside this)
- **Total header height: ~90pt** (approximately **~90-100pt** with buffer)

**Fixed Size Modifiers:**
- ❌ No `.fixedSize()` modifiers found in the header content
- No explicit frame heights set on the main header elements

---

## 2. WhiteSheetContainer Architecture

**Location:** `Core/UI/Common/WhiteSheetContainer.swift`

**Current Structure:**
```swift
VStack(spacing: 0) {
  headerSection
    .background(headerBackground)
  
  content
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(contentBackground)
}
```

**Key Findings:**
- ✅ **Header is OUTSIDE any ScrollView** - it's positioned in a `VStack` above the content
- ✅ Header is **fixed/static** - it doesn't scroll with content
- ✅ Content area can contain its own `ScrollView` (as seen in ProgressTabView line 698)
- ✅ Header and content are **siblings**, not parent-child

**Implications of Wrapping Both in Single ScrollView:**

**Current Structure (Header Fixed):**
- ✅ Header always visible
- ✅ Content scrolls independently
- ✅ Simple layout, predictable behavior
- ❌ Cannot hide header on scroll

**Alternative (Both in ScrollView):**
- ✅ Can hide header on scroll (scroll-to-hide behavior)
- ✅ More content space when header hidden
- ❌ Header scrolls away completely (may need sticky behavior)
- ❌ More complex scroll position tracking needed
- ❌ Header would need to be inside ScrollView's coordinate space

**Best Approach for Scroll-Responsive Header:**
- Keep header **outside** ScrollView (current structure)
- Use **scroll offset tracking** via `GeometryReader` or `PreferenceKey`
- Apply **transform/offset** to header based on scroll position
- This allows header to "slide up" while staying in fixed position relative to container

---

## 3. Scroll Position Tracking

**Current Implementation:**
- ❌ **No scroll position tracking** currently implemented in `ProgressTabView` or `WhiteSheetContainer`
- ✅ `GeometryReader` is used in ProgressTabView (lines 627, 4870, 5054, 5073, 5321, 5340) but **NOT for scroll tracking** - used for chart layouts and gradient calculations

**Best Approach to Add Scroll Offset Detection:**

**Option 1: PreferenceKey Pattern (Recommended)**
```swift
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// In ScrollView:
ScrollView {
    content
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).minY
                )
            }
        )
}
.coordinateSpace(name: "scroll")
.onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
    // Update header visibility based on offset
}
```

**Option 2: GeometryReader with CoordinateSpace**
```swift
ScrollView {
    content
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    let offset = geometry.frame(in: .global).minY
                    // Track offset
                }
            }
        )
}
```

**Option 3: ScrollViewReader (iOS 14+)**
- Less suitable for continuous scroll tracking
- Better for programmatic scrolling to specific positions

**Recommendation:** Use **PreferenceKey pattern** - it's the most SwiftUI-idiomatic approach and provides clean separation of concerns.

---

## 4. Header Height Calculation

**Detailed Breakdown:**

**Habit Selector Section:**
- Top padding: `12pt`
- Text height: `~20-22pt` (16pt font with semibold weight, accounting for line height)
- Image height: `24pt` (explicit frame)
- HStack intrinsic spacing: `0pt` (spacing: 0)
- **Subtotal: ~56-58pt**

**Tab Bar Section:**
- Top padding: `16pt`
- Button vertical padding: `12pt * 2 = 24pt`
- Text height: `~18-20pt` (14pt font with semibold weight)
- Underline stroke: `4pt` (explicit frame height)
- Bottom padding: `0pt`
- **Subtotal: ~62-64pt**

**VStack Spacing:**
- Spacing between elements: `0pt` (VStack spacing: 0)
- But implicit spacing from padding: `16pt` (tab bar top padding acts as spacing)

**Total Combined Height:**
- **~90pt** (approximately **~90-100pt** with buffer)

**For Animation Offset:**
- Use **~100pt** as the hide/show animation offset (includes buffer)
- The header should translate upward by this amount to fully hide

---

## 5. Component Separation

**Current Structure:**
```swift
VStack(spacing: 0) {
  // First Filter - Habit Selection
  HStack { ... }  // Habit selector
  
  // Second Filter - Period Selection  
  UnifiedTabBarView(...)  // Tab bar
}
```

**Can They Be Animated Independently?**

✅ **YES** - They are already in separate view hierarchies:
- Habit selector is in its own `HStack`
- Tab bar is a separate `UnifiedTabBarView`
- They're siblings in a `VStack`, not nested

**Implementation Approach:**
```swift
@State private var habitSelectorOffset: CGFloat = 0
@State private var tabBarOffset: CGFloat = 0

VStack(spacing: 0) {
  HStack { ... }  // Habit selector
    .offset(y: habitSelectorOffset)
    .opacity(habitSelectorOffset < -50 ? 0 : 1)
  
  UnifiedTabBarView(...)  // Tab bar
    .offset(y: tabBarOffset)
    .opacity(tabBarOffset < -50 ? 0 : 1)
}
```

**Use Cases:**
- **Collapse only habit selector** - Keep tabs visible for quick period switching
- **Collapse both** - Maximum content space
- **Staged collapse** - Habit selector hides first, then tabs (progressive reveal)

**Recommendation:** Start with **both collapsing together** for simplicity, but the architecture supports independent animation if needed.

---

## 6. Impact on Other Tabs

**Current Usage:**

1. **HomeTabView** (`Views/Tabs/HomeTabView.swift`, line 343)
   - Uses `WhiteSheetContainer` with `headerContent` containing:
     - `ExpandableCalendar`
     - `statsRowSection` (currently `EmptyView()`)
   - Has its own `ScrollView` in content

2. **HabitsTabView** (`Views/Tabs/HabitsTabView.swift`, line 46)
   - Uses `WhiteSheetContainer` with `title: "Habits"` and `headerContent` containing:
     - Stats row with tabs (Active/Inactive)
     - Edit button
   - Uses native `List` (which has built-in scrolling)

3. **ProgressTabView** (`Views/Tabs/ProgressTabView.swift`, line 692)
   - Uses `WhiteSheetContainer` with `headerContent` containing:
     - Habit selector
     - Period tabs (Daily/Weekly/Monthly/Yearly)
   - Has `ScrollView` in content

**Should Scroll-Responsive Behavior Be at WhiteSheetContainer Level?**

**Arguments FOR Container-Level Implementation:**
- ✅ **Reusability** - All three tabs would benefit from scroll-responsive headers
- ✅ **Consistency** - Uniform behavior across the app
- ✅ **DRY Principle** - Single implementation, easier maintenance
- ✅ **Future-proof** - New tabs automatically get the feature

**Arguments AGAINST (ProgressTabView-Specific):**
- ❌ **Different header needs** - HomeTabView has calendar (may want different behavior)
- ❌ **Complexity** - Not all tabs may need scroll-responsive headers
- ❌ **Performance** - Adds overhead even when not needed

**Recommendation: Hybrid Approach**

1. **Add optional scroll-responsive behavior to `WhiteSheetContainer`**
   - New parameter: `scrollResponsive: Bool = false`
   - New parameter: `headerCollapseThreshold: CGFloat = 100`
   - Only activates when explicitly enabled

2. **Implementation:**
```swift
struct WhiteSheetContainer<Content: View>: View {
  let scrollResponsive: Bool
  let headerCollapseThreshold: CGFloat
  
  // Add scroll tracking when scrollResponsive == true
  // Apply transforms to headerSection based on scroll offset
}
```

3. **Usage:**
```swift
// ProgressTabView - enable scroll-responsive
WhiteSheetContainer(
  headerContent: { ... },
  scrollResponsive: true,
  headerCollapseThreshold: 50
) { ... }

// HomeTabView - keep current behavior
WhiteSheetContainer(
  headerContent: { ... },
  scrollResponsive: false  // or omit (defaults to false)
) { ... }
```

**Benefits:**
- ✅ Reusable but opt-in
- ✅ No breaking changes
- ✅ Each tab can choose its behavior
- ✅ Can be enabled per-tab as needed

---

## Summary

1. **Header Structure:** VStack with habit selector (~56-60pt) and tab bar (~64pt), total ~120-124pt
2. **WhiteSheetContainer:** Header is fixed outside ScrollView; content scrolls independently
3. **Scroll Tracking:** Not currently implemented; use PreferenceKey pattern for best results
4. **Header Height:** ~120pt total (use ~130pt with buffer for animation offset)
5. **Component Separation:** Yes, can animate independently (they're siblings in VStack)
6. **Container-Level Implementation:** Recommended as **optional feature** with opt-in parameter
