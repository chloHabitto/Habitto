import SwiftUI

// MARK: - SubscriptionView

struct SubscriptionView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ZStack(alignment: .bottom) {
        ScrollView {
          VStack(spacing: 0) {
            // Header text
            headerText
              .padding(.top, 32)
              .padding(.bottom, 32)
            
            // Comparison table
            comparisonTable
              .padding(.bottom, 100) // Space for button
          }
          .padding(.horizontal, 20)
        }
        .background(Color.surface2)
        
        // Call-to-action button at bottom
        ctaButton
          .padding(.horizontal, 20)
          .padding(.bottom, 40)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  
  private var headerText: some View {
    Text("Unlock your full Habitto experience with Premium")
      .font(.appHeadlineSmallEmphasised)
      .foregroundColor(.text01)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
  }
  
  private var comparisonTable: some View {
    GeometryReader { geometry in
      ZStack {
        // Free column background
        HStack(spacing: 0) {
          Spacer()
            .frame(maxWidth: .infinity)
          
          Color.surface
            .frame(width: 80)
            .cornerRadius(16)
            .mask(
              VStack(spacing: 0) {
                // Header row
                Rectangle()
                  .frame(height: 48)
                
                // Feature rows
                ForEach(subscriptionFeatures, id: \.title) { _ in
                  Rectangle()
                    .frame(height: 56)
                }
              }
            )
          
          // Premium column gradient background
          LinearGradient(
            gradient: Gradient(colors: [
              Color(hex: "8E2AF9"), // Purple
              Color(hex: "F92A95")  // Pink/Orange
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(width: 100)
          .cornerRadius(16)
          .mask(
            VStack(spacing: 0) {
              // Header row
              Rectangle()
                .frame(height: 48)
              
              // Feature rows
              ForEach(subscriptionFeatures, id: \.title) { _ in
                Rectangle()
                  .frame(height: 56)
              }
            }
          )
        }
        
        // Main table
      VStack(spacing: 0) {
        // Table header
        HStack(spacing: 0) {
          Text("Benefits")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface)
          
          Text("Free")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
            .frame(width: 80, alignment: .center)
            .background(Color.blue)
          
          Text("Premium")
            .font(.appBodyMedium)
            .foregroundColor(.white)
            .frame(width: 100, alignment: .center)
            .background(Color.red)
        }
        .padding(.vertical, 16)
        
        // Table rows
        ForEach(subscriptionFeatures, id: \.title) { feature in
          comparisonRow(feature: feature)
        }
      }
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.outline3, lineWidth: 1)
      )
      }
    }
  }
  
  private func comparisonRow(feature: SubscriptionFeature) -> some View {
    HStack(spacing: 0) {
      // Benefit name
      Text(feature.title)
        .font(.appBodyMedium)
        .foregroundColor(.text01)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface)
      
      // Free column - transparent background so container shows through
      Group {
        if let freeText = feature.freeText {
          Text(freeText)
            .font(.appBodyMedium)
            .foregroundColor(.text01)
        } else {
          featureIcon(isAvailable: feature.isFreeAvailable, isPremium: false)
        }
      }
      .frame(width: 80, alignment: .center)
      .background(Color.blue)
      
      // Premium column - transparent background so gradient shows through
      featureIcon(isAvailable: feature.isPremiumAvailable, isPremium: true)
        .frame(width: 100, alignment: .center)
        .background(Color.red)
    }
    .padding(.vertical, 16)
    .overlay(
      Rectangle()
        .frame(height: 1)
        .foregroundColor(.outline3),
      alignment: .bottom
    )
  }
  
  private func featureIcon(isAvailable: Bool, isPremium: Bool) -> some View {
    if isAvailable {
      Image(systemName: "checkmark")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(isPremium ? .white : Color(hex: "FF7838")) // White for premium, orange for free
    } else {
      Image(systemName: "xmark")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.text04) // Grey cross
    }
  }
  
  private var ctaButton: some View {
    Button(action: {
      // Handle subscription action
      print("Start subscription tapped")
    }) {
      Text("Start my free week")
        .font(.appButtonText1)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.text01) // Black button
        .cornerRadius(16)
    }
  }
  
  private let subscriptionFeatures: [SubscriptionFeature] = [
    SubscriptionFeature(
      title: "Unlimited Habits",
      freeText: "5 max",
      isFreeAvailable: true,
      isPremiumAvailable: true
    ),
    SubscriptionFeature(
      title: "Progress Insights",
      isFreeAvailable: false,
      isPremiumAvailable: true
    ),
    SubscriptionFeature(
      title: "Deeper Insights",
      isFreeAvailable: false,
      isPremiumAvailable: true
    ),
    SubscriptionFeature(
      title: "Vacation Mode",
      isFreeAvailable: false,
      isPremiumAvailable: true
    ),
    SubscriptionFeature(
      title: "All Future Features",
      isFreeAvailable: false,
      isPremiumAvailable: true
    )
  ]
}

// MARK: - SubscriptionFeature

struct SubscriptionFeature {
  let title: String
  let freeText: String?
  let isFreeAvailable: Bool
  let isPremiumAvailable: Bool
  
  init(title: String, freeText: String? = nil, isFreeAvailable: Bool, isPremiumAvailable: Bool) {
    self.title = title
    self.freeText = freeText
    self.isFreeAvailable = isFreeAvailable
    self.isPremiumAvailable = isPremiumAvailable
  }
}

