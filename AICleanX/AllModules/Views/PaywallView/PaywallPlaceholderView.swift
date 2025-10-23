import SwiftUI

struct PaywallView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel: PaywallViewModel
    
    @State private var selectedPlan: PurchaseServiceProduct = ConfigService.shared.isProSubs ? .monthPRO : .month
    
    @State private var closeButtonOpacity: Double = 0.0

    private let scrollBottomID = "BottomAnchor"

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: PaywallViewModel(isPresented: isPresented))
    }

    var body: some View {
        ZStack {
            CMColor.background
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            
                            HStack(alignment: .top) {
                                Spacer().frame(width: 50)
                                    
                                Spacer()
                                    
                                Image("paywallImage")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width * 0.675)
                                    .cornerRadius(10)
                                    
                                Spacer()
                                    
                                CloseButtonView(isPresented: $isPresented)
                                    .opacity(closeButtonOpacity)
                                    .animation(.easeIn(duration: 0.3), value: closeButtonOpacity)
                            }
                            .padding(.top, 15)
                            .padding(.leading, 10)

                            PaywallMarketingBlockView()
                                .padding(.top, 10)
                            
                            SubscriptionSelectorView(
                                viewModel: viewModel,
                                selectedPlan: $selectedPlan
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 25)
                            
                            // Добавленный текст
                            Text("Premium free for 3 days:\nTry 3 days free")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(CMColor.primary)
                                .padding(.top, 10)
                                .multilineTextAlignment(.center)

                            Text("-- Cancel anytime --")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(CMColor.secondaryText.opacity(0.6))
                                .padding(.top, 5)
                                .padding(.bottom, 20)
                                .id(scrollBottomID)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    VStack(spacing: 0) {
                        PaywallContinueButton(action: {
                            if ConfigService.shared.isProSubs {
                                viewModel.continueTapped(with: selectedPlan == .monthPRO ? .monthPRO : .weekPRO)
                            } else {
                                viewModel.continueTapped(with: selectedPlan == .month ? .month : .week)
                            }
                        })
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                        
                        PaywallBottomLinksView(isPresented: $isPresented, viewModel: viewModel)
                            .padding(.vertical, 10)
                    }
                }
                
                .onAppear {
                    self.closeButtonOpacity = 1.0 // todo решил не прятать кнопку
                    // Появление кнопки закрытия через 2 секунды
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.closeButtonOpacity = 1.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            proxy.scrollTo(scrollBottomID, anchor: .bottom)
                        }
                    }
                }
            }
            if viewModel.isLoading {
                ProgressOverlayView()
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - 1.
struct CloseButtonView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20))
                    .foregroundColor(CMColor.secondaryText.opacity(0.5))
                    .padding(10)
            }
            Spacer()
        }
        .frame(width: 50, height: 50)
    }
}


// MARK: - 2.
struct PaywallMarketingBlockView: View {
    let features = [
        "Free up gigabytes of hidden junk — get speed and space for your favorite apps!",
        "Auto-delete blurry photos and bad videos — keep only the best, save up to 50% storage!",
        "Encrypt private media in a secret vault — save ~30% battery!"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text("Unlock All Premium Features")
                .font(.largeTitle.bold())
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(CMColor.primary)
                            .font(.system(size: 18))
                        Text(feature)
                            .font(.body)
                            .foregroundColor(CMColor.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 3.
struct SubscriptionSelectorView: View {
    @ObservedObject var viewModel: PaywallViewModel
    @Binding var selectedPlan: PurchaseServiceProduct

    var body: some View {
        HStack(spacing: 15) {
            PlanButton(
                title: "Weekly",
                price: viewModel.weekPrice,
                subtitle: "",
                plan: ConfigService.shared.isProSubs ? .weekPRO : .week,
                selectedPlan: $selectedPlan,
                showBadge: false
            )
            .frame(minWidth: 0, maxWidth: .infinity)

            PlanButton(
                title: "Monthly",
                price: viewModel.monthPrice,
                subtitle: "(\(viewModel.monthPricePerWeek) / week)",
                plan: ConfigService.shared.isProSubs ? .monthPRO : .month,
                selectedPlan: $selectedPlan,
                showBadge: true
            )
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(height: 150)
    }
}

// MARK: -
struct PlanButton: View {
    let title: String
    let price: String
    let subtitle: String
    let plan: PurchaseServiceProduct
    @Binding var selectedPlan: PurchaseServiceProduct
    let showBadge: Bool

    var isSelected: Bool {
        selectedPlan == plan
    }

    var body: some View {
        Button(action: {
            selectedPlan = plan
        }) {
            ZStack(alignment: .top) {
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline.bold())
                        .foregroundColor(isSelected ? CMColor.primary : CMColor.primaryText)
                    
                    Text(price)
                        .font(.title2.bold())
                        .foregroundColor(CMColor.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(CMColor.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(CMColor.surface)
                        .shadow(color: CMColor.black.opacity(0.1), radius: 5, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected ? CMColor.primary : CMColor.surface.opacity(0.5), lineWidth: isSelected ? 3 : 1)
                )
                .scaleEffect(isSelected ? 1.03 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                if showBadge {
                    Text("BEST OFFER")
                        .font(.caption.bold())
                        .foregroundColor(CMColor.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(CMColor.primary)
                        .cornerRadius(5)
                        .offset(y: -10)
                }
            }
        }
    }
}

// MARK: - 4.
struct PaywallContinueButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Continue")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(CMColor.primary)
                .cornerRadius(30)
        }
    }
}

// MARK: - 5.
struct PaywallBottomLinksView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: PaywallViewModel
    
    var body: some View {
        HStack(spacing: 15) {
            Spacer()

            Button("Privacy") {
                viewModel.privacyPolicyTapped()
            }
            
            Spacer()
            
            Button("Restore") {
                viewModel.restoreTapped()
            }
            
            Spacer()
            
            Button("Terms") {
                viewModel.licenseAgreementTapped()
            }
            
            Spacer()
        }
        .font(.system(size: 12))
        .foregroundColor(CMColor.secondaryText)
        .padding(.horizontal, 70)
    }
}
