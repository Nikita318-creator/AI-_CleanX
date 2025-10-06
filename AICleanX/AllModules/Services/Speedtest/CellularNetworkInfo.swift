import Foundation

/// Информация о сотовой сети
public struct CellularNetworkInfo: Identifiable, Hashable {
    public let id = UUID()
    public let type: CellularCardType
    public let parameters: [CellularParameter]
    
    public init(type: CellularCardType, parameters: [CellularParameter]) {
        self.type = type
        self.parameters = parameters
    }
}

/// Параметр сотовой сети
public struct CellularParameter: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let value: String
    
    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }
}

/// Тип сотовой карты
public enum CellularCardType: Int, CaseIterable {
    case physical = 0
    case eSIM = 1
    
    public var displayTitle: String {
        switch self {
        case .physical:
            return "Физическая SIM-карта"
        case .eSIM:
            return "Электронная SIM-карта (eSIM)"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .physical:
            return "Physical"
        case .eSIM:
            return "eSIM"
        }
    }
}

/// Категории информации о сотовой сети
public enum CellularInfoCategory: String, CaseIterable {
    case carrierName = "carrier"
    case mobileCountryCode = "mcc"
    case mobileNetworkCode = "mnc"
    case isoCountryCode = "country_code"
    case allowsVOIP = "voip_support"
    case currentRadioAccessTechnology = "connection_type"
    
    public var displayTitle: String {
        switch self {
        case .carrierName:
            return "Оператор связи"
        case .mobileCountryCode:
            return "Код страны (MCC)"
        case .mobileNetworkCode:
            return "Код сети (MNC)"
        case .isoCountryCode:
            return "Код страны (ISO)"
        case .allowsVOIP:
            return "Поддержка VoIP"
        case .currentRadioAccessTechnology:
            return "Тип подключения"
        }
    }
    
    public var errorMessage: String {
        switch self {
        case .carrierName:
            return "Ошибка получения оператора"
        case .mobileCountryCode:
            return "Ошибка получения MCC"
        case .mobileNetworkCode:
            return "Ошибка получения MNC"
        case .isoCountryCode:
            return "Ошибка получения ISO кода"
        case .allowsVOIP:
            return "Ошибка получения VoIP информации"
        case .currentRadioAccessTechnology:
            return "Ошибка определения типа подключения"
        }
    }
}
