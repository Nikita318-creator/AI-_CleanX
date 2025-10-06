import SwiftUI
import Combine

// MARK: - PaywallViewModel: Handles the business logic for the paywall view
final class PaywallViewModel: ObservableObject {
    
    // MARK: - Private Properties
    
    private let purchaseService = ApphudPurchaseService()
    private let isPresentedBinding: Binding<Bool>

    // MARK: - Published Properties
    
    @Published var weekPrice: String = "N/A"
    @Published var month3Price: String = "N/A" // NEW
    @Published var yearPrice: String = "N/A" // NEW
    
    @Published var weekPricePerDay: String = "N/A"
    @Published var month3PricePerDay: String = "N/A" // NEW
    @Published var yearPricePerDay: String = "N/A" // NEW
    
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
    func continueTapped(with plan: SubscriptionPlan) {
        purchaseService.purchase(plan: plan) { [weak self] result in
            guard let self = self else { return }
            
            if case .failure(let error) = result {
                print("Error during purchase: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.dismissPaywall()
        }
    }
    
    /// Handles the restore purchases button tap action.
    @MainActor
    func restoreTapped() {
        purchaseService.restore() { [weak self] result in
            guard let self = self else { return }
            
            if case .failure(let error) = result {
                print("Error during restore: \(error?.localizedDescription ?? "Unknown error")")
                // Still dismiss the paywall on restore failure as per common UX
                self.dismissPaywall()
                return
            }
            
            self.dismissPaywall()
        }
    }
    
    /// Opens the license agreement URL.
    func licenseAgreementTapped() {
        guard let url = URL(string: ResurcesUrlsConstants.licenseAgreementURL) else { return }
        UIApplication.shared.open(url)
    }
    
    /// Opens the privacy policy URL.
    func privacyPolicyTapped() {
        guard let url = URL(string: ResurcesUrlsConstants.privacyPolicyURL) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Private Methods
    
    /// Asynchronously updates all price-related published properties.
    private func updatePrices() async {
        // Wait for Apphud products to be fetched
        // This simulates a slight delay that might occur in a real app
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.weekPrice = purchaseService.localizedPrice(for: .week) ?? "N/A"
            self.month3Price = purchaseService.localizedPrice(for: .month3) ?? "N/A" // NEW
            self.yearPrice = purchaseService.localizedPrice(for: .year) ?? "N/A" // NEW
            
            self.weekPricePerDay = purchaseService.perDayPrice(for: .week)
            self.month3PricePerDay = purchaseService.perDayPrice(for: .month3) // NEW
            self.yearPricePerDay = purchaseService.perDayPrice(for: .year) // NEW
        }
    }
    
    /// Dismisses the paywall view.
    private func dismissPaywall() {
        isPresentedBinding.wrappedValue = false
    }
}
