import SwiftUI
import Combine

enum UrlsConstants {
    static let privacy = "https://sites.google.com/view/icecleanerai"
    static let terms = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
}

// MARK: - PaywallViewModel: Handles the business logic for the paywall view
final class PaywallViewModel: ObservableObject {
    
    // MARK: - Private Properties
    
    private let isPresentedBinding: Binding<Bool>

    // MARK: - Published Properties
    
    @Published var weekPrice: String = "N/A"
    @Published var monthPrice: String = "N/A" // NEW
    @Published var monthPricePerWeek: String = "N/A" // NEW
    
    // MARK: - Initialization
    
    init(isPresented: Binding<Bool>) {
        self.isPresentedBinding = isPresented
        
        Task {
            await updatePrices()
        }
    }
    
    // MARK: - Public Actions
    
    /// Handles the purchase button tap action.
    @MainActor
    func continueTapped(with plan: PurchaseServiceProduct) {
        ApphudPurchaseService.shared.purchase(plan: plan) { [weak self] result in
            guard let self = self else { return }
            
            if case .failure(let error) = result {
                print("Error during purchase: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.dismissPaywall()
        }
    }
    
    @MainActor
    func restoreTapped() {
        ApphudPurchaseService.shared.restore() { [weak self] result in
            guard let self = self else { return }
            
            if case .failure(let error) = result {
                print("Error during restore: \(error?.localizedDescription ?? "Unknown error")")
//                // todo test111 показать алерт?
                return
            }
            
            self.dismissPaywall()
        }
    }
    
    /// Opens the license agreement URL.
    func licenseAgreementTapped() {
        guard let url = URL(string: UrlsConstants.terms) else { return }
        UIApplication.shared.open(url)
    }
    
    /// Opens the privacy policy URL.
    func privacyPolicyTapped() {
        guard let url = URL(string: UrlsConstants.privacy) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Private Methods
    
    private func updatePrices() async {
        await MainActor.run {
            self.weekPrice = ApphudPurchaseService.shared.localizedPrice(for: .week) ?? "N/A"
            self.monthPrice = ApphudPurchaseService.shared.localizedPrice(for: .month) ?? "N/A"
            self.monthPricePerWeek = ApphudPurchaseService.shared.perWeekPrice(for: .month) ?? "N/A"
        }
    }
    
    private func dismissPaywall() {
        isPresentedBinding.wrappedValue = false
    }
}
