
import Foundation
import AppsFlyerLib

class AppsFlyerManager: NSObject {
    
    static let shared = AppsFlyerManager()
    
    private override init() {
        super.init()
    }
    
    /// Первичная конфигурация
    func configure() {
        AppsFlyerLib.shared().initialize(devKey: "cF5pJ5PNiKimBodGWu2GDn", appId: "6753745740")
        AppsFlyerLib.shared().delegate = self
        
        AppsFlyerLib.shared().isDebug = false
        #if DEBUG
        AppsFlyerLib.shared().isDebug = true
        #endif

        print("[AppsFlyer] configured")
    }
    
    /// Старт трекинга после ответа на ATT
    func start() {
        DispatchQueue.main.async {
            AppsFlyerLib.shared().registerSessionReadyListener {
                print("[AppsFlyer] Session is ready to start")
                AppsFlyerLib.shared().start()
            }
        }
    }
    
    // MARK: - Tracking Events
    
    func trackEvent(name: String, values: [String: Any]? = nil) {
        AppsFlyerLib.shared().logEvent(name, withValues: values)
    }
    
    func trackSubscriptionPurchase(price: Double, currency: String, productId: String) {
        let values: [String: Any] = [
            AFEventParamRevenue: price,
            AFEventParamCurrency: currency,
            AFEventParamContentId: productId
        ]
        trackEvent(name: AFEventPurchase, values: values)
        print("[AppsFlyer] trackSubscriptionPurchase: price = \(price), currency = \(currency), productId = \(productId)")
    }
}

// MARK: - AppsFlyerLibDelegate
extension AppsFlyerManager: AppsFlyerLibDelegate {
    
    @objc func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        print("[AppsFlyer] Conversion Data: \(conversionInfo)")
        
        // Основные параметры
        let status = conversionInfo["af_status"] as? String ?? "unknown"
        let afMessage = conversionInfo["af_message"] as? String ?? "unknown"
        let mediaSource = conversionInfo["media_source"] as? String ?? "unknown"
        let campaign = conversionInfo["campaign"] as? String ?? "unknown"
        
        // Безопасно приводим к строке любой тип (Bool/Int), который может вернуть флаер
        let isFirstLaunch = conversionInfo["is_first_launch"] != nil ? "\(conversionInfo["is_first_launch"]!)" : "unknown"
        let isCache = conversionInfo["iscache"] != nil ? "\(conversionInfo["iscache"]!)" : "unknown"
        
        // Данные креативов и групп (критично для FB / TikTok / Google Ads)
        let adset = conversionInfo["adset"] as? String ?? "unknown"
        let adsetId = conversionInfo["adset_id"] as? String ?? "unknown"
        let adgroup = conversionInfo["adgroup"] as? String ?? "unknown"
        let adgroupId = conversionInfo["adgroup_id"] as? String ?? "unknown"
        let ad = conversionInfo["ad"] as? String ?? "unknown"
        let adId = conversionInfo["ad_id"] as? String ?? "unknown"
                
        // Закидываем абсолютно всё в аналитику плоским словарем
        AnalyticService.shared.logEvent(
            name: "appsflyer_conversion_success",
            properties: [
                "af_status": status,
                "af_message": afMessage,
                "media_source": mediaSource,
                "campaign": campaign,
                "is_first_launch": isFirstLaunch,
                "iscache": isCache,
                "adset": adset,
                "adset_id": adsetId,
                "adgroup": adgroup,
                "adgroup_id": adgroupId,
                "ad": ad,
                "ad_id": adId
            ]
        )
    }
    
    @objc func onConversionDataFail(_ error: Error) {
        print("[AppsFlyer] Conversion Error: \(error.localizedDescription)")
        
        // Логируем ошибку, чтобы сразу видеть, если что-то отвалилось на бэке AppsFlyer
        AnalyticService.shared.logEvent(
            name: "appsflyer_conversion_fail",
            properties: [
                "error_description": error.localizedDescription
            ]
        )
    }
}
