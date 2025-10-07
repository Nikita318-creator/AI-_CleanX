import SwiftUI
import Combine
import SafariServices
import StoreKit

// Структура для данных онбординг-экрана
struct OnboardingScreen: Identifiable {
    let id = UUID()
    let title: String
    let highlightedPart: String
    let subtitle: String
    let imageName: String?
    let isLastScreen: Bool // Добавляем флаг для последнего экрана
}

final class OnboardingViewModel: ObservableObject {
    let screens: [OnboardingScreen] = [
        OnboardingScreen(
            title: "Secure your personal space",
            highlightedPart: "Secure your personal space",
            subtitle: "Store important files, photos and contacts in a hidden folder. Only you have the key.",
            imageName: "onboarding1",
            isLastScreen: false
        ),
        OnboardingScreen(
            title: "Test your internet speed",
            highlightedPart: "Test your internet speed",
            subtitle: "See if you really get what you pay for from your provider.",
            imageName: "onboarding2",
            isLastScreen: false
        ),
        OnboardingScreen(
            title: "Smart gallery cleanup",
            highlightedPart: "Smart gallery cleanup",
            subtitle: "Spot repeated shots and remove them effortlessly.",
            imageName: "onboarding3",
            isLastScreen: true
        )
    ]
    
    func licenseAgreementTapped() {
        guard let url = URL(string: UrlsConstants.terms) else { return }
        UIApplication.shared.open(url)
    }
    
    func privacyPolicyTapped() {
        guard let url = URL(string: UrlsConstants.privacy) else { return }
        UIApplication.shared.open(url)
    }
 
    @MainActor
    func restoreTapped() {
        let purchaseService = ApphudPurchaseService()

        purchaseService.restore() { [weak self] result in
            switch result {
            case .failure(let error):
                print("Error purchasing: \(error?.localizedDescription ?? "Unknown error")")
                self?.closePaywall()
                return
            case .success:
                self?.closePaywall()
            }
        }
    }
    
    private func closePaywall() {
        // do nothing
    }
}
