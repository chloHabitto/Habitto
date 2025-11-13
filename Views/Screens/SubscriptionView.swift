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
              .padding(.bottom, 32)
            
            // Subscription options
            subscriptionOptions
              .padding(.bottom, 100) // Space for button
            
            // Benefits list (commented out for future use)
            // benefitsList
            //   .padding(.bottom, 32)
          }
          .padding(.horizontal, 20)
        }
        .background(
          Image("LightLightBlueGradient@4x")
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
        .padding(.bottom, 8)
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
    (Text("Unlock your full Habitto experience with ") +
     Text("Premium")
       .font(.system(size: 28, weight: .black))
       .foregroundStyle(
         LinearGradient(
           gradient: Gradient(colors: [
             Color(hex: "74ADFA"),
             Color(hex: "183288")
           ]),
           startPoint: .top,
           endPoint: .bottom
         )
       ) +
     Text("")
    )
    .font(.appHeadlineMediumEmphasised)
    .foregroundColor(.text01)
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
  }
  
  private var benefitsList: some View {
    VStack(alignment: .leading, spacing: 16) {
      ForEach(subscriptionFeatures, id: \.title) { feature in
        HStack(spacing: 12) {
          // Premium check icon
          if feature.isPremiumAvailable {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(
                LinearGradient(
                  gradient: Gradient(colors: [
                    Color(hex: "74ADFA"),
                    Color(hex: "183288")
                  ]),
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
          }
          
          // Benefit title
          Text(feature.title)
            .font(.appBodyMedium)
            .foregroundColor(.text01)
        }
      }
    }
  }
  
  private var subscriptionOptions: some View {
    VStack(spacing: 12) {
      // Lifetime Access
      subscriptionOptionCard(
        emoji: "💎",
        title: "Lifetime Access",
        price: "€24.99",
        badge: "Popular",
        showBadge: true,
        showCrossedPrice: false
      )
      
      // Annual
      subscriptionOptionCard(
        emoji: "",
        title: "Annual",
        price: "€12.99/year",
        originalPrice: "€23.88",
        badge: "50% off",
        showBadge: true,
        showCrossedPrice: true
      )
      
      // Monthly
      subscriptionOptionCard(
        emoji: "",
        title: "Monthly",
        price: "€1.99/month",
        badge: nil,
        showBadge: false,
        showCrossedPrice: false
      )
    }
  }
  
  private func subscriptionOptionCard(
    emoji: String,
    title: String,
    price: String,
    originalPrice: String? = nil,
    badge: String?,
    showBadge: Bool,
    showCrossedPrice: Bool
  ) -> some View {
    HStack {
      if !emoji.isEmpty {
        Text(emoji)
          .font(.system(size: 24))
      }
      
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(title)
            .font(.appBodyMedium)
            .foregroundColor(.text01)
          
          if showBadge, let badge = badge {
            Text(badge)
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                LinearGradient(
                  gradient: Gradient(colors: [
                    Color(hex: "74ADFA"),
                    Color(hex: "183288")
                  ]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .cornerRadius(8)
          }
        }
        
        HStack(spacing: 8) {
          if showCrossedPrice, let originalPrice = originalPrice {
            Text(originalPrice)
              .font(.appBodySmall)
              .foregroundColor(.text04)
              .strikethrough()
          }
          
          Text(price)
            .font(.appBodyMedium)
            .foregroundColor(.text01)
        }
      }
      
      Spacer()
    }
    .padding(16)
    .background(Color.surface)
    .cornerRadius(12)
  }
  
  // MARK: - Comparison Table
  
  private var comparisonTable: some View {
    let tableHeight = CGFloat(56 + (56 * subscriptionFeatures.count))
    
    return ZStack {
        // Free column background
        HStack(spacing: 0) {
          Spacer()
            .frame(maxWidth: .infinity)
          
          VStack(spacing: 0) {
            // Header row background
            Color.navy50
              .opacity(0.4)
              .frame(height: 56)
            
            // Feature rows background
            ForEach(subscriptionFeatures, id: \.title) { _ in
              Color.navy50
                .opacity(0.4)
                .frame(height: 56)
            }
          }
          .frame(width: 80)
          .cornerRadius(16)
          
          // Premium column gradient background
          Image("blueGradient")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 100, height: CGFloat(56 + (56 * subscriptionFeatures.count)))
            .clipped()
            .cornerRadius(16)
        }
        
        // Main table
      VStack(spacing: 0) {
        // Table header
        HStack(spacing: 0) {
          Text("Benefits")
            .font(.appTitleSmallEmphasised)
            .fontWeight(.black)
            .foregroundColor(.text02)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
          
          Text("Free")
            .font(.appTitleSmallEmphasised)
            .fontWeight(.black)
            .foregroundColor(.text02)
            .frame(width: 80, alignment: .center)
            .background(Color.clear)
          
          Text("Premium")
            .font(.appTitleSmallEmphasised)
            .fontWeight(.black)
            .foregroundColor(.black)
            .frame(width: 100, alignment: .center)
            .background(Color.clear)
        }
        .padding(.vertical, 16)
        .frame(height: 56)
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
    .frame(height: tableHeight)
  }
  
  private func comparisonRow(feature: SubscriptionFeature, isLast: Bool) -> some View {
    HStack(spacing: 0) {
      // Benefit name
      Text(feature.title)
        .font(.appBodyMedium)
        .foregroundColor(.text01)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
      
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
    .frame(height: 56)
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
  
  @ViewBuilder
  private func featureIcon(isAvailable: Bool, isPremium: Bool) -> some View {
    if isAvailable {
      if isPremium {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(
            LinearGradient(
              gradient: Gradient(colors: [
                Color(hex: "74ADFA"),
                Color(hex: "183288")
              ]),
              startPoint: .top,
              endPoint: .bottom
            )
          )
      } else {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(Color(hex: "FF7838")) // Orange for free
      }
    } else {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.text04) // Grey cross
        .opacity(0.5)
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

