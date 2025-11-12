# Button Styles Comparison: Streak & Add Buttons

## Version 0.3.2 (Original - Before Glass Effect Changes)

### Streak Button (`HeaderView.swift`)
```swift
Button(action: onStreakTap) {
  HStack(spacing: 6) {
    // Icon: 32x32
    Image(.iconFire) // or "Icon-fire-frozen" when vacation active
      .resizable()
      .frame(width: 32, height: 32)
    
    Text(pluralizeStreak(currentStreak))
      .font(.appButtonText1)
      .foregroundColor(.black)  // Black text
  }
  .padding(.top, 8)
  .padding(.bottom, 8)
  .padding(.leading, 12)
  .padding(.trailing, 16)
  .background(Color.white)  // Solid white background
  .clipShape(Capsule())
}
.buttonStyle(PlainButtonStyle())
```

**Key Details:**
- **Icon**: `Image(.iconFire)` or `"Icon-fire-frozen"` (32x32)
- **Text**: `.appButtonText1` font, `.black` color
- **Background**: Solid `Color.white`
- **Shape**: Capsule
- **Padding**: Individual padding values (top: 8, bottom: 8, leading: 12, trailing: 16)

---

### Add Button (`HeaderView.swift`)
```swift
Button(action: onCreateHabit) {
  Image("Icon-AddCircle_Filled")
    .renderingMode(.template)
    .resizable()
    .frame(width: 32, height: 32)
    .foregroundColor(.onPrimary)  // Uses semantic color
}
.frame(width: 44, height: 44)
// NO BACKGROUND - transparent
```

**Key Details:**
- **Icon**: `"Icon-AddCircle_Filled"` (32x32)
- **Foreground**: `.onPrimary` (semantic color)
- **Frame**: 44x44
- **Background**: None (transparent)

---

### Add Button (`HomeTabView.swift`)
```swift
Button(action: { ... }) {
  Image("Icon-AddCircle_Filled")
    .renderingMode(.template)
    .resizable()
    .frame(width: 28, height: 28)
    .foregroundColor(.onPrimary)  // Uses semantic color
}
.frame(width: 44, height: 44)
.buttonStyle(PlainButtonStyle())
// NO BACKGROUND - transparent
```

**Key Details:**
- **Icon**: `"Icon-AddCircle_Filled"` (28x28 - smaller than HeaderView)
- **Foreground**: `.onPrimary` (semantic color)
- **Frame**: 44x44
- **Background**: None (transparent)

---

## Backup Branch (Before Revert - Advanced Glass Effects)

### Streak Button (`HeaderView.swift`)
```swift
Button(action: onStreakTap) {
  HStack(spacing: 6) {
    // Icon: 24x24 (SMALLER)
    Image(.iconFire)
      .resizable()
      .frame(width: 24, height: 24)
    
    Text(pluralizeStreak(currentStreak))
      .font(.appButtonText1)
      .foregroundColor(.white)  // WHITE text (not black)
  }
  .padding(.horizontal, 12)
  .frame(height: 48)  // Fixed height
  .background {
    // iOS glass effect using Material
    RoundedRectangle(cornerRadius: 24)
      .fill(.ultraThinMaterial)
      .overlay {
        // Liquid glass effect with gradient opacity stroke
        RoundedRectangle(cornerRadius: 24)
          .stroke(
            LinearGradient(
              stops: [
                .init(color: Color.white.opacity(0.4), location: 0.0),  // Top-left: stronger
                .init(color: Color.white.opacity(0.1), location: 0.5),  // Center: weaker
                .init(color: Color.white.opacity(0.4), location: 1.0)   // Bottom-right: stronger
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1.5
          )
      }
  }
}
.buttonStyle(PlainButtonStyle())
```

**Key Details:**
- **Icon**: `Image(.iconFire)` (24x24 - smaller)
- **Text**: `.appButtonText1` font, `.white` color (not black)
- **Background**: `.ultraThinMaterial` with gradient border
- **Shape**: `RoundedRectangle(cornerRadius: 24)` (not Capsule)
- **Border**: Gradient stroke (0.4 → 0.1 → 0.4 opacity), lineWidth: 1.5
- **Padding**: `.padding(.horizontal, 12)` + `.frame(height: 48)`

---

### Add Button (`HeaderView.swift` - Backup Branch)
```swift
Button(action: onCreateHabit) {
  Image(systemName: "plus")  // SF Symbol (not Icon-AddCircle_Filled)
    .font(.system(size: 16, weight: .bold))
    .foregroundColor(.white)  // White (not .onPrimary)
}
.frame(width: 40, height: 40)  // Smaller (40x40, not 44x44)
.background {
  // iOS glass effect using Material
  Circle()
    .fill(.ultraThinMaterial)
    .overlay {
      // Liquid glass effect with gradient opacity stroke
      Circle()
        .stroke(
          LinearGradient(
            stops: [
              .init(color: Color.white.opacity(0.4), location: 0.0),
              .init(color: Color.white.opacity(0.1), location: 0.5),
              .init(color: Color.white.opacity(0.4), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1.5
        )
    }
}
```

**Key Details:**
- **Icon**: `Image(systemName: "plus")` (SF Symbol, not custom icon)
- **Font**: `.system(size: 16, weight: .bold)`
- **Foreground**: `.white` (not `.onPrimary`)
- **Frame**: 40x40 (smaller)
- **Background**: `.ultraThinMaterial` with gradient border
- **Border**: Gradient stroke (0.4 → 0.1 → 0.4 opacity), lineWidth: 1.5

---

### Add Button (`HomeTabView.swift` - Backup Branch)
```swift
Button(action: { ... }) {
  Image("Icon-AddCircle_Filled")
    .renderingMode(.template)
    .resizable()
    .frame(width: 28, height: 28)
    .foregroundColor(Color.white)  // Explicit white (not .onPrimary)
}
.frame(width: 44, height: 44)
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Add new habit")
.accessibilityHint("Double tap to create a new habit")
// NO GLASS EFFECT - transparent
```

**Key Details:**
- **Icon**: `"Icon-AddCircle_Filled"` (28x28)
- **Foreground**: `Color.white` (explicit, not `.onPrimary`)
- **Frame**: 44x44
- **Background**: None (transparent)
- **Accessibility**: Has accessibility labels

---

## Current State (0.3.2 + Simple Glass Effect - What We Just Added)

### Streak Button (`HeaderView.swift`)
```swift
Button(action: onStreakTap) {
  HStack(spacing: 6) {
    Image(.iconFire)
      .resizable()
      .frame(width: 32, height: 32)  // Original size
    Text(pluralizeStreak(currentStreak))
      .font(.appButtonText1)
      .foregroundColor(.black)  // Original black text
  }
  .padding(.top, 8)
  .padding(.bottom, 8)
  .padding(.leading, 12)
  .padding(.trailing, 16)
  .background(.ultraThinMaterial, in: Capsule())  // Simple glass effect
  .overlay(
    Capsule()
      .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)  // Simple border
  )
}
.buttonStyle(PlainButtonStyle())
```

**Key Details:**
- **Icon**: `Image(.iconFire)` (32x32 - original size)
- **Text**: `.appButtonText1` font, `.black` color (original)
- **Background**: `.ultraThinMaterial` (simple glass)
- **Border**: Simple white stroke (0.2 opacity, lineWidth: 1)
- **Shape**: Capsule (original)

---

### Add Button (`HeaderView.swift` - Current)
```swift
Button(action: onCreateHabit) {
  Image("Icon-AddCircle_Filled")
    .renderingMode(.template)
    .resizable()
    .frame(width: 32, height: 32)
    .foregroundColor(.onPrimary)  // Original semantic color
}
.frame(width: 44, height: 44)  // Original size
.background(.ultraThinMaterial, in: Circle())  // Simple glass effect
.overlay(
  Circle()
    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)  // Simple border
)
```

**Key Details:**
- **Icon**: `"Icon-AddCircle_Filled"` (32x32 - original)
- **Foreground**: `.onPrimary` (original semantic color)
- **Frame**: 44x44 (original)
- **Background**: `.ultraThinMaterial` (simple glass)
- **Border**: Simple white stroke (0.2 opacity, lineWidth: 1)

---

### Add Button (`HomeTabView.swift` - Current)
```swift
Button(action: { ... }) {
  Image("Icon-AddCircle_Filled")
    .renderingMode(.template)
    .resizable()
    .frame(width: 28, height: 28)
    .foregroundColor(.onPrimary)  // Original semantic color
}
.frame(width: 44, height: 44)
.background(.ultraThinMaterial, in: Circle())  // Simple glass effect
.overlay(
  Circle()
    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)  // Simple border
)
.buttonStyle(PlainButtonStyle())
```

**Key Details:**
- **Icon**: `"Icon-AddCircle_Filled"` (28x28 - original)
- **Foreground**: `.onPrimary` (original semantic color)
- **Frame**: 44x44 (original)
- **Background**: `.ultraThinMaterial` (simple glass)
- **Border**: Simple white stroke (0.2 opacity, lineWidth: 1)

---

## Summary of Differences

### Version 0.3.2 (Original)
- **Streak**: Solid white background, black text, 32x32 icon
- **Add (HeaderView)**: No background, `.onPrimary` color, 32x32 icon, 44x44 frame
- **Add (HomeTabView)**: No background, `.onPrimary` color, 28x28 icon, 44x44 frame

### Backup Branch (Advanced Glass)
- **Streak**: Glass effect with gradient border, white text, 24x24 icon, height: 48, RoundedRectangle
- **Add (HeaderView)**: Glass effect with gradient border, SF Symbol "plus", white color, 40x40 frame
- **Add (HomeTabView)**: No glass effect, white color, 28x28 icon, 44x44 frame, accessibility labels

### Current State (Simple Glass)
- **Streak**: Simple glass effect, black text, 32x32 icon, Capsule shape (preserves original)
- **Add (HeaderView)**: Simple glass effect, `.onPrimary` color, 32x32 icon, 44x44 frame (preserves original)
- **Add (HomeTabView)**: Simple glass effect, `.onPrimary` color, 28x28 icon, 44x44 frame (preserves original)

---

## Recommendations

1. **If you want the advanced glass effect from backup branch:**
   - Use gradient border (0.4 → 0.1 → 0.4 opacity)
   - Use white text for streak button
   - Consider smaller icon sizes (24x24 for streak, 40x40 for add button)
   - Use `RoundedRectangle(cornerRadius: 24)` for streak button

2. **If you want to keep current simple glass effect:**
   - Keep original icon sizes and text colors
   - Keep simple white border (0.2 opacity)
   - Maintain original padding and frame sizes

3. **If you want original 0.3.2 style:**
   - Remove glass effects entirely
   - Use solid white background for streak button
   - Remove backgrounds from add buttons

