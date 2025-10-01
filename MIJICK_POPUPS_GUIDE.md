# MijickPopups Integration Guide

## 📦 What is MijickPopups?

MijickPopups is a SwiftUI framework that simplifies presenting popups, alerts, toasts, banners, and bottom sheets with beautiful animations and gestures.

**GitHub:** https://github.com/Mijick/Popups.git

---

## ✅ Setup Complete

### 1. Package Added
✅ MijickPopups package added to project

### 2. App Configuration
✅ Import added to `HabittoApp.swift`:
```swift
import MijickPopups
```

✅ Configured in your app:
```swift
HomeView()
    .environmentObject(...)
    .implementPopupView() // ← Enables MijickPopups
```

---

## 🚀 How to Use MijickPopups

### **Three Types of Popups:**

1. **BottomPopup** - Slides from bottom (sheets, selections)
2. **CentrePopup** - Appears in center (alerts, confirmations)
3. **TopPopup** - Slides from top (toasts, notifications, banners)

---

## 📝 Example 1: Bottom Popup (Sheet Style)

### **Create the Popup:**
```swift
struct ReminderSelectionPopup: BottomPopup {
    let onReminderSelected: (Date) -> Void
    @State private var selectedTime = Date()
    
    func createContent() -> some View {
        VStack(spacing: 20) {
            // Header
            Text("Set Reminder")
                .font(.appHeadingMedium)
                .foregroundColor(.text01)
                .padding(.top, 24)
            
            // Time Picker
            DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
            
            // Confirm Button
            HabittoButton.largeFillPrimary(
                text: "Set Reminder",
                action: {
                    onReminderSelected(selectedTime)
                    dismiss() // ← Dismisses the popup
                }
            )
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .background(Color.surface)
    }
    
    func configurePopup(popup: BottomPopupConfig) -> BottomPopupConfig {
        popup
            .cornerRadius(20)
            .dragGestureEnabled(true)
            .tapOutsideToDismiss(true)
    }
}
```

### **Show the Popup:**
```swift
Button("Add Reminder") {
    ReminderSelectionPopup { selectedTime in
        print("Selected time: \(selectedTime)")
    }
    .present() // ← Single line to show!
}
```

---

## 📝 Example 2: Center Popup (Alert Style)

### **Create the Popup:**
```swift
struct DeleteConfirmationPopup: CentrePopup {
    let habitName: String
    let onConfirm: () -> Void
    
    func createContent() -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Delete Habit")
                    .font(.appHeadingMedium)
                    .foregroundColor(.text01)
                
                Text("Are you sure you want to delete '\(habitName)'? This cannot be undone.")
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.appButtonText1)
                .foregroundColor(.text03)
                .frame(maxWidth: .infinity, height: 48)
                .background(Color.surfaceContainer)
                .cornerRadius(12)
                
                Button("Delete") {
                    onConfirm()
                    dismiss()
                }
                .font(.appButtonText1)
                .foregroundColor(.onPrimary)
                .frame(maxWidth: .infinity, height: 48)
                .background(Color.red)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(Color.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 20)
    }
    
    func configurePopup(popup: CentrePopupConfig) -> CentrePopupConfig {
        popup
            .tapOutsideToDismiss(false) // Can't dismiss by tapping outside
            .backgroundColour(.black.opacity(0.4))
    }
}
```

### **Show the Popup:**
```swift
Button("Delete Habit") {
    DeleteConfirmationPopup(habitName: "Exercise") {
        // Delete the habit
    }
    .present()
}
```

---

## 📝 Example 3: Top Popup (Toast/Banner Style)

### **Create the Popup:**
```swift
struct SuccessToast: TopPopup {
    let message: String
    
    func createContent() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            Text(message)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8)
        .padding(.horizontal, 20)
    }
    
    func configurePopup(popup: TopPopupConfig) -> TopPopupConfig {
        popup
            .dismissAfter(2.0) // Auto-dismiss after 2 seconds
            .dragGestureEnabled(true)
    }
}
```

### **Show the Popup:**
```swift
Button("Save") {
    // Save logic...
    
    SuccessToast(message: "Habit saved successfully!")
        .present()
}
```

---

## 🎯 When to Use MijickPopups vs Native Sheets

### **Use MijickPopups for:**

✅ **Toasts/Notifications** (top banners)
```swift
SuccessToast(message: "Saved!").present()
```

✅ **Quick Confirmations** (center alerts)
```swift
DeleteConfirmationPopup(...).present()
```

✅ **Stackable Popups** (multiple popups at once)
```swift
Toast1().present()
Toast2().present() // Both visible!
```

✅ **Custom Gestures & Animations**
- Drag to resize
- Custom transitions
- Auto-dismiss timers

### **Keep Native Sheets for:**

✅ **Complex Forms** (HabitEditView, CreateHabitView)
- Better keyboard handling
- Native iOS feel
- System integration

✅ **Full-Screen Modals**
- Login flows
- Onboarding
- Settings screens

---

## 🔄 Migration Example

### **Before (Native Sheet):**
```swift
@State private var showingReminder = false

.sheet(isPresented: $showingReminder) {
    ReminderBottomSheet(...)
}

Button("Add Reminder") {
    showingReminder = true
}
```

### **After (MijickPopups):**
```swift
// No @State needed!

Button("Add Reminder") {
    ReminderSelectionPopup { time in
        // Handle selected time
    }
    .present() // ← One line!
}
```

---

## 🎨 Customization Options

### **Height Modes:**
```swift
func configurePopup(popup: BottomPopupConfig) -> BottomPopupConfig {
    popup
        .heightMode(.auto)        // Fits content
        .heightMode(.large)       // 70% of screen
        .heightMode(.fullscreen)  // Full screen
}
```

### **Gestures:**
```swift
.dragGestureEnabled(true)         // Swipe down to dismiss
.tapOutsideToDismiss(true)        // Tap outside to dismiss
.dismissAfter(3.0)                // Auto-dismiss after 3 seconds
```

### **Appearance:**
```swift
.cornerRadius(20)
.backgroundColour(.black.opacity(0.3))
.contentIgnoresSafeArea(false)
```

---

## 💡 Best Practices for Habitto

### **1. Use for Success Toasts:**
```swift
// After completing a habit
SuccessToast(message: "Habit completed! +10 XP")
    .present()
```

### **2. Use for Quick Confirmations:**
```swift
// Before deleting a reminder
DeleteReminderPopup(onConfirm: { ... })
    .present()
```

### **3. Use for Stacked Notifications:**
```swift
// Show multiple achievements
AchievementToast("7-day streak!").present()
AchievementToast("Level up!").present()
// Both show at once!
```

### **4. Keep Native Sheets for:**
- `HabitEditView` (complex form)
- `CreateHabitFlowView` (multi-step)
- `ReminderBottomSheet` (complex time picker)
- `TutorialBottomSheet` (full-screen tutorial)

---

## 🔍 Testing

To verify MijickPopups is working:

```swift
// Add this button anywhere temporarily
Button("Test Popup") {
    ExampleBottomPopup(
        title: "Test",
        message: "MijickPopups is working!",
        onConfirm: {}
    )
    .present()
}
```

---

## 📚 Resources

- **Documentation:** https://github.com/Mijick/Popups
- **Examples:** See `ExampleMijickPopup.swift`
- **Your Current Sheets:** `Core/UI/BottomSheets/`

---

## ✨ Summary

✅ MijickPopups configured in `HabittoApp.swift`  
✅ Example popups created in `ExampleMijickPopup.swift`  
✅ Ready to use anywhere with `.present()`  

**Next Steps:**
1. Test the example popups
2. Decide which sheets to migrate (toasts, simple alerts)
3. Keep complex forms as native sheets
4. Enjoy cleaner code! 🎉

