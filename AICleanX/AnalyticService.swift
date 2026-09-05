import Amplitude
import AdSupport
import AppTrackingTransparency

enum EnvironmentAmplitude {
    case prod
    case dev
}

class AnalyticService {
    static let shared = AnalyticService()
    private var isTrackingAuthorized = false
    
    private init() {}
    
    // todo
    let environment: EnvironmentAmplitude = .prod
    
    func logEvent(name: String, properties: [AnyHashable : Any]) {
        guard environment == .prod else { return }
        
        if !isTrackingAuthorized {
            requestTrackingAuthorization()
//            return // todo return it after test AnalyticService
        }
        
        var versionText = "V:"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            versionText += " \(version)(\(build)) "
        }
        
        var eventProperties: [AnyHashable : Any] = properties
        eventProperties["version: "] = versionText

        Amplitude.instance().logEvent(name, withEventProperties: eventProperties)
    }
    
    func requestTrackingAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            switch status {
            case .authorized:
                self?.isTrackingAuthorized = true
                print("[AppsFlyer] ATTrackingManager.requestTrackingAuthorization result granted with status \(status)")
                AppsFlyerManager.shared.start()
            case .denied, .restricted:
                self?.isTrackingAuthorized = false
                print("[AppsFlyer] ATTrackingManager.requestTrackingAuthorization result granted with status \(status)")
                AppsFlyerManager.shared.start()
            case .notDetermined:
                self?.isTrackingAuthorized = false
            @unknown default:
                self?.isTrackingAuthorized = false
            }
            
            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            print("[IDFA] Мой тестовый айфон: \(idfa)")
        }
    }
}
