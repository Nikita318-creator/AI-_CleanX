import SwiftUI
import Combine
import SafariServices
import StoreKit

enum ResurcesUrlsConstants {
    static let licenseAgreementURL: String = "https://docs.google.com/document/d/1Bui27Z99LoyQN86Kal7rI1S65T0x-UTrM619Kufuom4/edit?usp=sharing"
    static let privacyPolicyURL: String = "https://docs.google.com/document/d/1UgJhUk01_cvZK3x0626_x65HXoirR4mEU9RrJw_1ZLI/edit?usp=sharing"
    static let contactUsEmail: String = ""
}

final class SettingsViewModel: ObservableObject {
    
    @Published var isPasscodeEnabledInApp: Bool = false
    @Published var isFaceIDInAppEnabled: Bool = false
    @Published var isSecretSpacePasscodeEnabled: Bool = true
    @Published var isSecretSpaceFaceIDEnabled: Bool = true
    
    func rateUsTapped() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    func licenseAgreementTapped() {
        guard let url = URL(string: ResurcesUrlsConstants.licenseAgreementURL) else { return }
        UIApplication.shared.open(url)
    }
    
    func privacyPolicyTapped() {
        guard let url = URL(string: ResurcesUrlsConstants.privacyPolicyURL) else { return }
        UIApplication.shared.open(url)
    }
    
    func sendFeedbackTapped() {
        let subject = "Feedback"
        let body = ""
        let mailtoString = "mailto:\(ResurcesUrlsConstants.contactUsEmail)?subject=\(subject)&body=\(body)"
        
        if let mailtoUrl = URL(string: mailtoString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            UIApplication.shared.open(mailtoUrl)
        }
    }
}
