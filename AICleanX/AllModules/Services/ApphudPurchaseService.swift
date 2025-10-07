import StoreKit
import ApphudSDK
import Combine

// MARK: - App Constants and Types

/// Defines the supported subscription product types.
// todo PRO
enum PurchaseServiceProduct: String, CaseIterable {
    case week = "1"
    case month = "2"
}

/// Defines the outcome of a purchase or restore operation.
enum PurchaseServiceResult {
    case success
    case failure(Error?)
}

/// Custom errors for the purchase flow.
enum PurchaseError: Error {
    case cancelled
    case noProductsFound
    case productNotFound(String)
    case purchaseFailed
    case noActiveSubscription
}

// MARK: - SKProduct Extension: Price and Currency Helpers

public extension SKProduct {
    /// The localized price string for the product.
    var localizedPrice: String? {
        return PriceFormatter.formatter.string(from: price)
    }

    /// The currency symbol for the product.
    var currency: String {
        return PriceFormatter.formatter.currencySymbol
    }

    private struct PriceFormatter {
        static let formatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.locale = Locale.current
            formatter.numberStyle = .currency
            return formatter
        }()
    }
}

// MARK: - ApphudPurchaseService: Manages all Apphud transactions

final class ApphudPurchaseService {
    
    // Typealias for method signature clarity.
    typealias PurchaseCompletion = (PurchaseServiceResult) -> Void
    
    // MARK: - Properties
    
    // Store fetched Apphud products.
    private var availableProducts: [ApphudProduct] = []

    /// Checks if the user has an active subscription.
    var hasActiveSubscription: Bool {
        true // todo: test111
//        Apphud.hasActiveSubscription()
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await fetchProducts()
        }
    }
    
    // MARK: - Public API

    /// Purchases a subscription plan.
    @MainActor
    func purchase(plan: PurchaseServiceProduct, completion: @escaping PurchaseCompletion) {
        guard let productId = getProductId(for: plan) else {
            completion(.failure(PurchaseError.noProductsFound))
            return
        }

        guard let product = getProduct(with: productId) else {
            completion(.failure(PurchaseError.productNotFound(productId)))
            return
        }

        Apphud.purchase(product) { [weak self] result in
            self?.handlePurchaseResult(result, completion: completion)
        }
    }
    
    /// Restores all purchases for the user.
    @MainActor
    func restore(completion: @escaping PurchaseCompletion) {
        Apphud.restorePurchases { [weak self] subscriptions, nonRenewingPurchases, error in
            self?.handleRestoreResult(subscriptions: subscriptions, error: error, completion: completion)
        }
    }
    
    /// Returns the numerical price for a given product.
    func price(for product: PurchaseServiceProduct) -> Double? {
        guard let skProduct = getSKProduct(for: product) else { return nil }
        return skProduct.price.doubleValue
    }
    
    /// Returns the localized price string for a given product.
    func localizedPrice(for product: PurchaseServiceProduct) -> String? {
        guard let skProduct = getSKProduct(for: product) else {
            // Fallback for when Apphud products are not available
            return "$1.99" // Updated fallback price
        }
        return skProduct.localizedPrice
    }
    
    /// Returns the currency symbol for a given product.
    func currency(for product: PurchaseServiceProduct) -> String? {
        guard let skProduct = getSKProduct(for: product) else { return nil }
        return skProduct.currency
    }

    /// Calculates and returns the per-day price string.
    func perDayPrice(for product: PurchaseServiceProduct) -> String {
        let defaultPerDayPrice = "$0.71" // Updated fallback per-day price
        
        guard let priceValue = price(for: product),
              let currencySymbol = currency(for: product) else {
            return defaultPerDayPrice
        }
        
        var days: Double
        switch product {
        case .week:
            days = 7.0
        case .month:
            days = 30.0 // Assuming 30 days for month
        }
        
        let perDay = priceValue / days
        
        // Formats the string with 2 decimal places
        return String(format: "%.2f%@", perDay, currencySymbol)
    }

    // MARK: - Private Methods

    private func getProductId(for plan: PurchaseServiceProduct) -> String? {
        // This function now needs to be adapted to the new `PurchaseServiceProduct` enum.
        // The `SubscriptionPlan` enum is no longer sufficient to map all products.
        // You will need to update the call site to pass in `PurchaseServiceProduct` directly.
        // Assuming there is a way to map old plans to new products:
        switch plan {
        case .week:
            return PurchaseServiceProduct.week.rawValue
        case .month:
            // This mapping is now ambiguous. Please update the `SubscriptionPlan` or the calling code.
            // For now, let's assume it's for 3-month plan.
            return PurchaseServiceProduct.month.rawValue
        }
    }

    private func getProduct(with id: String) -> ApphudProduct? {
        return availableProducts.first(where: { $0.productId == id })
    }

    private func getSKProduct(for product: PurchaseServiceProduct) -> SKProduct? {
        return getProduct(with: product.rawValue)?.skProduct
    }
    
    private func handlePurchaseResult(_ result: ApphudPurchaseResult, completion: @escaping PurchaseCompletion) {
        if let error = result.error {
            print("Apphud: Purchase failed with error: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        if let subscription = result.subscription, subscription.isActive() || result.nonRenewingPurchase != nil {
            print("Apphud: Purchase successful.")
            completion(.success)
        } else {
            print("Apphud: Purchase failed - unknown reason.")
            completion(.failure(PurchaseError.purchaseFailed))
        }
    }

    private func handleRestoreResult(subscriptions: [ApphudSubscription]?, error: Error?, completion: @escaping PurchaseCompletion) {
        if let restoreError = error {
            completion(.failure(restoreError))
            return
        }
        
        if subscriptions?.first(where: { $0.isActive() }) != nil {
            print("Apphud: Restore successful - active subscription found.")
            completion(.success)
        } else {
            print("Apphud: Restore completed, but no active subscription found.")
            completion(.failure(PurchaseError.noActiveSubscription))
        }
    }
    
    /// Asynchronously fetches Apphud products from the paywalls.
    func fetchProducts() async {
        let placements = await Apphud.placements(maxAttempts: 3)
        guard let paywall = placements.first?.paywall, !paywall.products.isEmpty else {
            print("Apphud: No products found on paywall.")
            return
        }
        
        self.availableProducts = paywall.products
        print("Apphud: Fetched products with IDs: \(self.availableProducts.map { $0.productId })")
        print()
    }
}
