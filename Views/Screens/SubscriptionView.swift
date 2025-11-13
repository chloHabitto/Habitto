import SwiftUI

// MARK: - SubscriptionView

struct SubscriptionView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ZStack(alignment: .bottom) {
        // Background
        Image("secondaryBlueGradient(top,bottom)@4x")
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .ignoresSafeArea(.all)
        
        ScrollView {
          VStack(spacing: 0) {
            // Header text
            headerText
              .padding(.top, 20)
              .padding(.bottom, 32)
            
            // Comparison table
            comparisonTable
              .padding(.bottom, 32)
            
            // Review carousel
            reviewCarousel
              .padding(.bottom, 100) // Space for button
            
            // Benefits list (commented out for future use)
            // benefitsList
            //   .padding(.bottom, 32)
          }
          .padding(.horizontal, 20)
        }
        
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
      .sheet(isPresented: $showingSubscriptionOptions) {
        subscriptionOptionsSheet
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var selectedOption: SubscriptionOption = .lifetime
  @State private var showingSubscriptionOptions = false
  @State private var currentReviewIndex: Int = 0
  
  private let reviews: [Review] = [
    Review(id: "1", text: "This app transformed my daily routine. Premium features are worth it!"),
    Review(id: "2", text: "Best habit tracker I've used. The insights are incredible."),
    Review(id: "3", text: "Love vacation mode! Perfect for breaks without losing my streak."),
    Review(id: "4", text: "Unlimited habits is a game changer. Highly recommend premium!")
  ]
  
  private var headerText: some View {
    (Text("Unlock your full Habitto experience with ")
       .foregroundColor(.text02.opacity(0.85)) +
     Text("Premium")
       .font(.system(size: 28, weight: .black))
       .foregroundColor(.primary) +
     Text("")
    )
    .font(.appHeadlineMedium)
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
  }
  
  private var reviewCarousel: some View {
    VStack(spacing: 16) {
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
              reviewCard(review: review)
                .id(index)
            }
          }
          .padding(.horizontal, 20)
        }
        .onAppear {
          proxy.scrollTo(currentReviewIndex, anchor: .center)
        }
        .onChange(of: currentReviewIndex) { _, newValue in
          withAnimation {
            proxy.scrollTo(newValue, anchor: .center)
          }
        }
      }
      .gesture(
        DragGesture()
          .onEnded { value in
            let threshold: CGFloat = 50
            if value.translation.width > threshold && currentReviewIndex > 0 {
              withAnimation {
                currentReviewIndex -= 1
              }
            } else if value.translation.width < -threshold && currentReviewIndex < reviews.count - 1 {
              withAnimation {
                currentReviewIndex += 1
              }
            }
          }
      )
      
      // Page controls
      HStack(spacing: 8) {
        ForEach(0..<reviews.count, id: \.self) { index in
          Circle()
            .fill(index == currentReviewIndex ? Color.primary : Color.outline3)
            .frame(width: 8, height: 8)
            .animation(.easeInOut(duration: 0.2), value: currentReviewIndex)
        }
      }
      .padding(.top, 8)
    }
  }
  
  private func reviewCard(review: Review) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      // 5 stars
      HStack(spacing: 4) {
        ForEach(0..<5) { _ in
          Image(systemName: "star.fill")
            .font(.system(size: 16))
            .foregroundColor(.yellow100)
        }
      }
      
      // Review text
      Text(review.text)
        .font(.appBodyMedium)
        .foregroundColor(.text01)
        .lineLimit(3)
    }
    .padding(16)
    .frame(width: 280)
    .background {
      // Liquid glass effect
      RoundedRectangle(cornerRadius: 12)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 12)
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
  
  private var subscriptionOptionsSheet: some View {
    NavigationView {
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 20) {
            // Profile image
            Image("Default-Profile@4x")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 80, height: 80)
              .clipShape(Circle())
            
            subscriptionOptions
          }
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, 20)
        }
        
        // Bottom buttons
        VStack(spacing: 12) {
          HabittoButton.largeFillPrimary(text: "Continue") {
            // Handle subscription action
            print("Continue subscription tapped")
            showingSubscriptionOptions = false
          }
          
          HabittoButton(
            size: .medium,
            style: .tertiary,
            content: .text("Maybe Later"),
            action: {
              showingSubscriptionOptions = false
            }
          )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .padding(.top, 12)
        .background(Color.surface)
      }
      .navigationTitle("Choose Your Plan")
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.height(650), .large])
    .presentationDragIndicator(.visible)
  }
  
  private var subscriptionOptions: some View {
    VStack(spacing: 12) {
      // Lifetime Access
      subscriptionOptionCard(
        option: .lifetime,
        emoji: "💎",
        title: "Lifetime Access",
        price: "€24.99",
        badge: "Popular",
        showBadge: true,
        showCrossedPrice: false
      )
      
      // Annual
      subscriptionOptionCard(
        option: .annual,
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
        option: .monthly,
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
    option: SubscriptionOption,
    emoji: String,
    title: String,
    price: String,
    originalPrice: String? = nil,
    badge: String?,
    showBadge: Bool,
    showCrossedPrice: Bool
  ) -> some View {
    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedOption = option
      }
    }) {
      HStack(spacing: 16) {
        // Radio button circle
        ZStack {
          Circle()
            .fill(selectedOption == option ? Color.primary : Color.clear)
            .frame(width: 24, height: 24)
            .animation(.easeInOut(duration: 0.2), value: selectedOption)
          
          Circle()
            .stroke(selectedOption == option ? Color.primary : Color.outline3, lineWidth: 2)
            .frame(width: 24, height: 24)
            .animation(.easeInOut(duration: 0.2), value: selectedOption)
          
          if selectedOption == option {
            Circle()
              .fill(Color.white)
              .frame(width: 8, height: 8)
              .animation(.easeInOut(duration: 0.2), value: selectedOption)
          }
        }
        
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
      .background(selectedOption == option ? Color.primary.opacity(0.05) : Color.surface)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(selectedOption == option ? Color.primary : Color.clear, lineWidth: 2)
      )
    }
    .buttonStyle(PlainButtonStyle())
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
          
          // Premium column background
          Color("pastelBlue100")
            .frame(width: 100, height: CGFloat(56 + (56 * subscriptionFeatures.count)))
            .cornerRadius(16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(Color("pastelBlue300"), lineWidth: 2)
            )
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
          .foregroundColor(Color("pastelBlue500"))
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
    HabittoButton.largeFillPrimary(text: "See all plans") {
      showingSubscriptionOptions = true
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

// MARK: - SubscriptionOption

enum SubscriptionOption {
  case lifetime
  case annual
  case monthly
}

// MARK: - Review

struct Review {
  let id: String
  let text: String
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

