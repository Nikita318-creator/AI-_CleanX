import Foundation
import SwiftUI
import StoreKit

class MainHelper {
    
    static let shared = MainHelper()
    
    var deletedItemsCount = 0
    
    var hasRequestedReviewFromSpeedTest: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "has_requested_app_review_FromSpeedTest")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "has_requested_app_review_FromSpeedTest")
        }
    }
    
    var hasRequestedReviewFromDeleteItems: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "has_requested_app_review_FromDeleteItems")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "has_requested_app_review_FromDeleteItems")
        }
    }
    
    private init() {}
    
    func requestReviewIfNeededFromSpeedTest() {
        guard !hasRequestedReviewFromSpeedTest, let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("Review already requested. Skipping.")
            return
        }

        SKStoreReviewController.requestReview(in: windowScene)        
        hasRequestedReviewFromSpeedTest = true
    }
    
    func requestReviewIfNeededFromDeleteItems() {
        guard !hasRequestedReviewFromDeleteItems, let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("Review already requested. Skipping.")
            return
        }

        SKStoreReviewController.requestReview(in: windowScene)
        hasRequestedReviewFromDeleteItems = true
    }
}
