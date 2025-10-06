import Foundation
import CoreTelephony

/// Провайдер информации о сотовой сети
public final class CellularInfoProvider: ObservableObject {
    
    @Published public private(set) var cellularInfo: [CellularNetworkInfo] = []
    @Published public private(set) var isLoading = false
    
    private let telephonyNetworkInfo = CTTelephonyNetworkInfo()
    
    public init() {
        loadCellularInfo()
    }
    
    /// Получить полную информацию о сотовых подключениях
    public func getCellularInformation() -> [CellularNetworkInfo] {
        return cellularInfo
    }
    
    /// Обновить информацию о сотовой сети
    public func refreshCellularInfo() {
        isLoading = true
        loadCellularInfo()
    }
    
    // MARK: - Private Methods
    
    private func loadCellularInfo() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let info = self?.fetchCellularInfo() ?? self?.createDefaultInfo() ?? []
            
            DispatchQueue.main.async {
                self?.cellularInfo = info
                self?.isLoading = false
            }
        }
    }
    
    private func fetchCellularInfo() -> [CellularNetworkInfo] {
        guard let providers = telephonyNetworkInfo.serviceSubscriberCellularProviders else {
            return createDefaultInfo()
        }
        
        var allInfo: [CellularNetworkInfo] = []
        
        for (index, provider) in providers.enumerated() {
            let isESIM = index != 0 // Первый провайдер обычно физическая SIM
            let carrier = provider.value
            let parameters = createParametersForCarrier(carrier)
            
            let info = CellularNetworkInfo(
                type: isESIM ? .eSIM : .physical,
                parameters: parameters
            )
            allInfo.append(info)
        }
        
        return allInfo.isEmpty ? createDefaultInfo() : allInfo
    }
    
    private func createParametersForCarrier(_ carrier: CTCarrier) -> [CellularParameter] {
        var parameters: [CellularParameter] = []
        
        for category in CellularInfoCategory.allCases {
            let value = getValueForCategory(category, carrier: carrier)
            let parameter = CellularParameter(
                title: category.displayTitle,
                value: value
            )
            parameters.append(parameter)
        }
        
        return parameters
    }
    
    private func getValueForCategory(_ category: CellularInfoCategory, carrier: CTCarrier) -> String {
        switch category {
        case .carrierName:
            return carrier.carrierName ?? "Не определено"
        case .mobileCountryCode:
            return carrier.mobileCountryCode ?? "Не определено"
        case .mobileNetworkCode:
            return carrier.mobileNetworkCode ?? "Не определено"
        case .isoCountryCode:
            return carrier.isoCountryCode ?? "Не определено"
        case .allowsVOIP:
            return carrier.allowsVOIP ? "Поддерживается" : "Не поддерживается"
        case .currentRadioAccessTechnology:
            return getCurrentNetworkType()
        }
    }
    
    private func getCurrentNetworkType() -> String {
        guard let radioAccessTechnology = telephonyNetworkInfo.serviceCurrentRadioAccessTechnology?.values.first else {
            return "Не подключен"
        }
        
        return convertRadioAccessTechnologyToReadableString(radioAccessTechnology)
    }
    
    private func convertRadioAccessTechnologyToReadableString(_ technology: String) -> String {
        switch technology {
        // 2G Technologies
        case CTRadioAccessTechnologyGPRS:
            return "2G (GPRS)"
        case CTRadioAccessTechnologyEdge:
            return "2G (EDGE)"
        case CTRadioAccessTechnologyCDMA1x:
            return "2G (CDMA 1x)"
            
        // 3G Technologies
        case CTRadioAccessTechnologyWCDMA:
            return "3G (WCDMA)"
        case CTRadioAccessTechnologyHSDPA:
            return "3G (HSDPA)"
        case CTRadioAccessTechnologyHSUPA:
            return "3G (HSUPA)"
        case CTRadioAccessTechnologyCDMAEVDORev0:
            return "3G (EVDO Rev 0)"
        case CTRadioAccessTechnologyCDMAEVDORevA:
            return "3G (EVDO Rev A)"
        case CTRadioAccessTechnologyCDMAEVDORevB:
            return "3G (EVDO Rev B)"
        case CTRadioAccessTechnologyeHRPD:
            return "3G (eHRPD)"
            
        // 4G Technologies
        case CTRadioAccessTechnologyLTE:
            return "4G (LTE)"
            
        default:
            if #available(iOS 14.1, *) {
                // 5G поддержка для iOS 14.1+
                if technology == "CTRadioAccessTechnologyNR" || technology == "CTRadioAccessTechnologyNRNSA" {
                    return "5G"
                }
            }
            return "Неизвестная технология"
        }
    }
    
    private func createDefaultInfo() -> [CellularNetworkInfo] {
        var parameters: [CellularParameter] = []
        
        for category in CellularInfoCategory.allCases {
            let parameter = CellularParameter(
                title: category.displayTitle,
                value: category.errorMessage
            )
            parameters.append(parameter)
        }
        
        return [CellularNetworkInfo(type: .physical, parameters: parameters)]
    }
}
