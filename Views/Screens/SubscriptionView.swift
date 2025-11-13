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
              .padding(.top, 16)
              .padding(.bottom, 32)
            
            // Comparison table
            comparisonTable
              .padding(.bottom, 100) // Space for button
          }
          .padding(.horizontal, 20)
        }
        .background(
          Image("Light-gradient-BG@4x")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
        )
        
        // Call-to-action buttons at bottom
        VStack(spacing: 12) {
          ctaButton
          restorePurchaseButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
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
      .font(.appHeadlineMediumEmphasised)
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
          
          Color.surface2
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
            .font(.appTitleSmallEmphasised)
            .foregroundColor(.text02)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface)
          
          Text("Free")
            .font(.appTitleSmallEmphasised)
            .foregroundColor(.text02)
            .frame(width: 80, alignment: .center)
            .background(Color.clear)
          
          Text("Premium")
            .font(.appTitleSmallEmphasised)
            .foregroundColor(.white)
            .frame(width: 100, alignment: .center)
            .background(Color.clear)
        }
        .padding(.vertical, 16)
        .overlay(
          Rectangle()
            .frame(height: 1)
            .foregroundColor(.outline3),
          alignment: .bottom
        )
        
        // Table rows
        ForEach(Array(subscriptionFeatures.enumerated()), id: \.element.title) { index, feature in
          comparisonRow(feature: feature, isLast: index == subscriptionFeatures.count - 1)
        }
      }
      .cornerRadius(16)
      }
    }
  }
  
  private func comparisonRow(feature: SubscriptionFeature, isLast: Bool) -> some View {
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
      .background(Color.clear)
      
      // Premium column - transparent background so gradient shows through
      featureIcon(isAvailable: feature.isPremiumAvailable, isPremium: true)
        .frame(width: 100, alignment: .center)
        .background(Color.clear)
    }
    .padding(.vertical, 16)
    .overlay(
      Group {
        if !isLast {
          Rectangle()
            .frame(height: 1)
            .foregroundColor(.outline3)
        }
      },
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
    HabittoButton.largeFillPrimary(text: "Continue") {
      // Handle subscription action
      print("Start subscription tapped")
    }
  }
  
  private var restorePurchaseButton: some View {
    HabittoButton(
      size: .medium,
      style: .outline,
      content: .text("Restore purchase")
    ) {
      // Handle restore purchase action
      print("Restore purchase tapped")
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

