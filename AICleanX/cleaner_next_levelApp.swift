import SwiftUI
import Amplitude
import ApphudSDK

@main
struct cleaner_next_levelApp: App {
    init() {
        // Amplitude:
        Amplitude.instance().initializeApiKey("285007276a8006bf1d7e4bc3edfb2bb8")
        Amplitude.instance().setServerZone(.EU)
        Amplitude.instance().trackingSessionEvents = true

        // Amplitude: Apphud
        Apphud.start(apiKey: "app_myFpmSbBsF6KFRuGe3hhRwNnr1eEp2")
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: idfv)
        
        _ = ApphudPurchaseService.shared // после старта работы так как там фетч внутри
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
