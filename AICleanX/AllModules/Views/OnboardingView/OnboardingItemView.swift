import SwiftUI
import AdSupport
import CoreData

struct OnboardingItemView: View {
    let screen: OnboardingScreen
    @Binding var onboardingShown: Bool
    @Binding var currentPage: Int
    let screenIndex: Int
    let screensCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            let parts = screen.title.components(separatedBy: screen.highlightedPart)
            
            if screenIndex == 2 {
                (Text(screen.highlightedPart)
                    .foregroundColor(CMColor.primary)
                 + Text(parts.last ?? "")
                    .foregroundColor(CMColor.black)
                )
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 35)
            } else {
                (Text(parts.first ?? "")
                    .foregroundColor(CMColor.black)
                 + Text(screen.highlightedPart)
                    .foregroundColor(CMColor.primary)
                 + Text(parts.last ?? "")
                    .foregroundColor(CMColor.black)
                )
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 35)
            }
            
            Text(screen.subtitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            
            if let imageName = screen.imageName {
                VStack(spacing: 0) {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(CMColor.accent)
                        .frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    Button(action: {
                        if screen.isLastScreen {
                            onboardingShown = true
                            AnalyticService.shared.logEvent(name: "paywall shown", properties: ["":""])
                        } else {
                            withAnimation {
                                currentPage += 1
                                AnalyticService.shared.logEvent(name: "onbording shown", properties: ["currentPage":"\(currentPage)"])
                            }
                        }
                    }) {
                        Text("Continue")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(CMColor.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(CMColor.primary)
                            .cornerRadius(30)
                    }
                    .padding(.horizontal, 30) // <-- Добавили внешний паддинг к кнопке
                }
                .padding(.top, 25)
                .padding(.bottom, 50)
            }
        }
    }
}
