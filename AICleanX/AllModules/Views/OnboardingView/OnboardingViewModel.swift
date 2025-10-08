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
    let screens: [OnboardingScreen] =
    // MARK: - Вариант 1: Более технический (Intelligent Organizer, Connection Performance, Data Protection Vault)
    [
        OnboardingScreen(
            title: "Intelligent photo and media organizer",
            highlightedPart: "Intelligent Photo & Media",
            subtitle: "",
            imageName: "onboard1",
            isLastScreen: true
        ),
        OnboardingScreen(
            title: "Check connection performance",
            highlightedPart: "Connection Performance",
            subtitle: "",
            imageName: "onboard2",
            isLastScreen: false
        ),
        OnboardingScreen(
            title: "Private data protection vault",
            highlightedPart: "Data Protection Vault",
            subtitle: "",
            imageName: "onboard3",
            isLastScreen: false
        ),
    ]
    // MARK: - вариант 2 - устрой А/Б тест
//    [
//        OnboardingScreen(
//            title: "Reclaim space with smart album analysis",
//            highlightedPart: "Reclaim Space",
//            subtitle: "",
//            imageName: "onboarding1",
//            isLastScreen: true
//        ),
//        OnboardingScreen(
//            title: "Verify your network velocity",
//            highlightedPart: "Network Velocity",
//            subtitle: "",
//            imageName: "onboarding2",
//            isLastScreen: false
//        ),
//        OnboardingScreen(
//            title: "Encrypt and shield your files",
//            highlightedPart: "Encrypt and Shield",
//            subtitle: "",
//            imageName: "onboarding3",
//            isLastScreen: false
//        ),
//    ]
    
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
