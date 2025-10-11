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
    
    @Published var isLoading: Bool = false

    // MARK: - Initialization
    
    init(isPresented: Binding<Bool>) {
        self.isPresentedBinding = isPresented
        
        Task {
            await updatePrices()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updatePricesOnPayWall),
            name: .updatePricesOnPayWallKey,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Actions
    
    /// Handles the purchase button tap action.
    @MainActor
    func continueTapped(with plan: PurchaseServiceProduct) {
        self.isLoading = true
        ApphudPurchaseService.shared.purchase(plan: plan) { [weak self] result in
            guard let self = self else { return }
            
            // 2. Снимаем флаг загрузки в любом случае
            self.isLoading = false
            
            if case .failure(let error) = result {
                AnalyticService.shared.logEvent(name: "paywall failure", properties: ["Error":"\(error?.localizedDescription ?? "Unknown error")"])
                print("Error during purchase: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            AnalyticService.shared.logEvent(name: "PURCHASED!!!", properties: ["plan":"\(plan.rawValue)"])

            // 3. Дизмисс Paywall только при успехе
            self.dismissPaywall()
        }
    }
    
    @MainActor
    func restoreTapped() {
        self.isLoading = true

        ApphudPurchaseService.shared.restore() { [weak self] result in
            guard let self = self else { return }
            
            // 2. Снимаем флаг загрузки в любом случае
            self.isLoading = false
            
            if case .failure(let error) = result {
                AnalyticService.shared.logEvent(name: "paywall failure", properties: ["Error":"Error during restore: \(error?.localizedDescription ?? "Unknown error")"])
                print("Error during restore: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            AnalyticService.shared.logEvent(name: "restore PURCHASes", properties: ["":""])

            // 3. Дизмисс Paywall только при успехе
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
        if ConfigService.shared.isProSubs {
            await MainActor.run {
                self.weekPrice = ApphudPurchaseService.shared.localizedPrice(for: .weekPRO) ?? "N/A"
                self.monthPrice = ApphudPurchaseService.shared.localizedPrice(for: .monthPRO) ?? "N/A"
                self.monthPricePerWeek = ApphudPurchaseService.shared.perWeekPrice(for: .monthPRO) ?? "N/A"
            }
        } else {
            await MainActor.run {
                self.weekPrice = ApphudPurchaseService.shared.localizedPrice(for: .week) ?? "N/A"
                self.monthPrice = ApphudPurchaseService.shared.localizedPrice(for: .month) ?? "N/A"
                self.monthPricePerWeek = ApphudPurchaseService.shared.perWeekPrice(for: .month) ?? "N/A"
            }
        }
    }
    
    private func dismissPaywall() {
        isPresentedBinding.wrappedValue = false
    }
    
    @objc private func updatePricesOnPayWall() {
        Task {
            await updatePrices()
        }
    }
}

extension Notification.Name {
    static let updatePricesOnPayWallKey = Notification.Name("updatePricesOnPayWallKey")
}
