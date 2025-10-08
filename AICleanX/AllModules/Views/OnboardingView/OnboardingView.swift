import SwiftUI
import AdSupport
import CoreData

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @AppStorage("onboardingShown") var onboardingShown: Bool = false
    @State private var currentPage: Int = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                ForEach(Array(viewModel.screens.enumerated()), id: \.offset) { index, screen in
                    OnboardingItemView(screen: screen, onboardingShown: $onboardingShown, currentPage: $currentPage, screenIndex: index, screensCount: viewModel.screens.count)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .background(.backgroundSecondary).ignoresSafeArea()
            
//            VStack {
//                Spacer()
//                HStack(spacing: 20) {
//                    Button(action: {
//                        viewModel.privacyPolicyTapped()
//                    }) {
//                        Text("Privacy Policy")
//                            .font(.system(size: 12, weight: .regular))
//                            .foregroundColor(CMColor.secondaryText)
//                    }
//                    
//                    Spacer()
//
//                    Button(action: {
//                        viewModel.restoreTapped()
//                    }) {
//                        Text("Restore")
//                            .font(.system(size: 12, weight: .regular))
//                            .foregroundColor(CMColor.secondaryText)
//                    }
//                    
//                    Spacer()
//
//                    Button(action: {
//                        viewModel.licenseAgreementTapped()
//                    }) {
//                        Text("Terms of Use")
//                            .font(.system(size: 12, weight: .regular))
//                            .foregroundColor(CMColor.secondaryText)
//                    }
//                }
//                .padding(.bottom, 20)
//                .padding(.horizontal, 40)
//            }
        }
    }
}
