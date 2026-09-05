import SwiftUI
import Amplitude
import ApphudSDK
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 1. Инициализация Firebase в AppDelegate
        FirebaseApp.configure()

        return true
    }
}

@main
struct cleaner_next_levelApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // Amplitude:
        Amplitude.instance().initializeApiKey("285007276a8006bf1d7e4bc3edfb2bb8")
        Amplitude.instance().setServerZone(.EU)
        Amplitude.instance().trackingSessionEvents = true

        AppsFlyerManager.shared.configure()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//            AppsFlyerManager.shared.trackSubscriptionPurchase(
//                price: 8,
//                currency: "USD",
//                productId: "75876848764"
//            )
//        }
        // Amplitude: Apphud
        Apphud.start(apiKey: "app_myFpmSbBsF6KFRuGe3hhRwNnr1eEp2")
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: idfv)
        
        _ = ApphudPurchaseService.shared // после старта работы так как там фетч внутри
        _ = ConfigService.shared
        _ = AnalyticService.shared
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            AnalyticService.shared.logEvent(name: "hasActiveSubscription: \(ApphudPurchaseService.shared.hasActiveSubscription)", properties: ["":""])
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
