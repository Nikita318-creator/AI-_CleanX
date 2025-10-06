import SwiftUI

enum SubscriptionPlan {
    case weekly
    case monthly3
    case yearly
}

struct PaywallView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel: PaywallViewModel

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: PaywallViewModel(isPresented: isPresented))
    }

    var body: some View {
        ZStack {
            CMColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PaywallHeaderView()
                    .padding(.top, 60)
                
                PaywallIconsBlockView()
                    .padding(.top, 20)
                
                PaywallFeaturesTagView()
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                VStack(spacing: 8) {
                    Text("100% FREE FOR 3 DAYS")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(CMColor.primary)
                    
                    Text("ZERO FEE WITH RISK FREE")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(CMColor.primary.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Text("NO EXTRA COST")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(CMColor.primary.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                Text("Try 3 days free, after $6.99/week\nCancel anytime")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CMColor.secondaryText.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)

                Spacer()
                
                PaywallContinueButton(action: {
                    viewModel.continueTapped(with: .weekly)
                })
                .padding(.horizontal, 20)
                
                PaywallBottomLinksView(isPresented: $isPresented, viewModel: viewModel)
                    .padding(.vertical, 10)
            }
            .padding(.bottom, 20)
            
            VStack {
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
                Spacer()
            }
            .padding(.top, 15)
            .padding(.leading, 10)
        }
    }
}

struct PaywallHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Premium Free")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(CMColor.primary)
            
            Text("for 3 days")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(CMColor.primary)
        }
    }
}

struct PaywallIconsBlockView: View {
    var body: some View {
        HStack(spacing: 20) {
            IconWithText(imageName: "PayWallImege1", text: "16.4 Gb")
            IconWithText(imageName: "PayWallImege2", text: "2.5 Gb")
            IconWithText(imageName: "PayWallImege3", text: "0.2 Gb")
        }
    }
}

struct IconWithText: View {
    let imageName: String
    let text: String
    
    var iconSize: CGFloat {
        return 100
    }
          
    var body: some View {
        VStack(spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(CMColor.iconPrimary)
            
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
        }
    }
}

struct PaywallFeaturesTagView: View {
    let features = [
        "Secret folder for your media & contacts",
        "Internet speed check",
        "Ad-free",
        "Fast cleanup. More space",
        "Complete info about your phone"
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            FeatureTagView(text: features[0])
            
            HStack(spacing: 10) {
                FeatureTagView(text: features[1])
                FeatureTagView(text: features[2])
            }
            
            FeatureTagView(text: features[3])
            FeatureTagView(text: features[4])
        }
    }
}

private struct FeatureTagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(CMColor.secondary.opacity(0.1))
            .cornerRadius(8)
            .foregroundColor(CMColor.secondary)
    }
}

struct PaywallContinueButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(CMColor.primary)
                .cornerRadius(8)
        }
    }
}

struct PaywallBottomLinksView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: PaywallViewModel
    
    var body: some View {
        HStack(spacing: 15) {
            Button("Privacy Policy") {
                viewModel.privacyPolicyTapped()
            }
            
            Spacer()
            
            Button("Restore") {
                viewModel.restoreTapped()
            }
            
            Spacer()
            
            Button("Terms of Use") {
                viewModel.licenseAgreementTapped()
            }
        }
        .font(.system(size: 12))
        .foregroundColor(CMColor.secondaryText)
        .padding(.horizontal, 40)
    }
}
