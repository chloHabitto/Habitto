import SwiftUI

// MARK: - CompletionInputSheet

struct CompletionInputSheet: View {
  // MARK: Lifecycle
  
  init(
    isPresented: Binding<Bool>,
    habit: Habit,
    date: Date,
    onSave: @escaping (Int) -> Void
  ) {
    self._isPresented = isPresented
    self.habit = habit
    self.date = date
    self.onSave = onSave
    
    // Initialize with current progress
    let currentProgress = habit.getProgress(for: date)
    self._completionCount = State(initialValue: currentProgress)
  }
  
  // MARK: Internal
  
  let habit: Habit
  let date: Date
  let onSave: (Int) -> Void
  
  var body: some View {
    VStack(spacing: 24) {
      // Title
      Text("Log Completion")
        .font(.appTitleMediumEmphasised)
        .foregroundColor(.text01)
        .padding(.top, 24)
      
      Spacer()
      
      // Input row
      HStack(spacing: 16) {
        // Decrement button
        Button(action: {
          if completionCount > 0 {
            completionCount -= 1
          }
        }) {
          Image(systemName: "minus")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.text01)
            .frame(width: 44, height: 44)
            .background(Color.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(completionCount <= 0)
        .opacity(completionCount <= 0 ? 0.5 : 1.0)
        
        // Input field
        VStack(spacing: 8) {
          TextField("", value: $completionCount, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.appTitleLarge)
            .foregroundColor(.text01)
            .frame(width: 80)
            .focused($isInputFocused)
            .onAppear {
              // Select all on appear for easy editing
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
              }
            }
          
          // Unit label
          Text(unitText)
            .font(.appBodyMedium)
            .foregroundColor(.text05)
        }
        
        // Increment button
        Button(action: {
          completionCount += 1
        }) {
          Image(systemName: "plus")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.text01)
            .frame(width: 44, height: 44)
            .background(Color.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
      }
      
      Spacer()
      
      // Done button
      HabittoButton(
        size: .large,
        style: .fillPrimary,
        content: .text("Done"),
        state: .default,
        hugging: false,
        action: {
          onSave(completionCount)
          isPresented = false
        }
      )
      .padding(.bottom, 24)
    }
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity)
    .background(Color.appSurface01Variant)
    .presentationDetents([.height(280)])
    .presentationDragIndicator(.hidden)
    .presentationCornerRadius(40)
  }
  
  // MARK: Private
  
  @Binding private var isPresented: Bool
  @State private var completionCount: Int
  @FocusState private var isInputFocused: Bool
  
  private var unitText: String {
    // Extract unit from habit goal
    // Goal format: "5 times on everyday", "20 pages on daily", etc.
    let goalString = habit.goal.lowercased()
    
    // Try to extract unit by splitting on " on " or " per "
    var unitPart = ""
    if let onIndex = goalString.range(of: " on ") {
      unitPart = String(goalString[..<onIndex.lowerBound])
    } else if let perIndex = goalString.range(of: " per ") {
      unitPart = String(goalString[..<perIndex.lowerBound])
    } else {
      unitPart = goalString
    }
    
    // Extract the unit word (everything after the number)
    let components = unitPart.components(separatedBy: " ")
    if components.count >= 2 {
      // Join all words except the first (the number)
      let unit = components.dropFirst().joined(separator: " ")
      return unit
    }
    
    return "times" // Default fallback
  }
  
  private var goalAmount: Int {
    habit.goalAmount(for: date)
  }
}

// MARK: - Preview

#Preview {
  struct PreviewWrapper: View {
    @State private var isPresented = true
    
    var body: some View {
      Text("Background")
        .sheet(isPresented: $isPresented) {
          CompletionInputSheet(
            isPresented: $isPresented,
            habit: Habit(
              name: "Read a book",
              description: "Read for 30 minutes",
              icon: "📚",
              color: .blue,
              habitType: .formation,
              schedule: "everyday",
              goal: "30 pages on everyday",
              reminder: "9:00 AM",
              startDate: Date(),
              endDate: nil
            ),
            date: Date(),
            onSave: { count in
              print("Saved count: \(count)")
            }
          )
        }
    }
  }
  
  return PreviewWrapper()
}
