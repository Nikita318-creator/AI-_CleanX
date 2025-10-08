import SwiftUI
import ApphudSDK

@main
struct cleaner_next_levelApp: App {
    init() {
        _ = ApphudPurchaseService.shared
        
        Apphud.start(apiKey: "app_myFpmSbBsF6KFRuGe3hhRwNnr1eEp2")
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: idfv)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
