import Foundation

/// Единицы измерения пропускной способности
public enum BandwidthUnit: Int, CaseIterable {
    case bitsPerSecond = 0
    case kilobitsPerSecond = 1
    case megabitsPerSecond = 2
    case gigabitsPerSecond = 3
    
    public var symbol: String {
        switch self {
        case .bitsPerSecond:
            return "bps"
        case .kilobitsPerSecond:
            return "Kbps"
        case .megabitsPerSecond:
            return "Mbps"
        case .gigabitsPerSecond:
            return "Gbps"
        }
    }
    
    public var conversionFactor: Double {
        return pow(1000.0, Double(rawValue))
    }
}

/// Структура для хранения измерений пропускной способности
public struct BandwidthMeasurement: CustomStringConvertible, Comparable {
    public let value: Double
    public let unit: BandwidthUnit
    
    private static let bitsInByte: Double = 8.0
    private static let unitStepSize: Double = 1000.0
    
    public init(value: Double, unit: BandwidthUnit) {
        self.value = value
        self.unit = unit
    }
    
    /// Создает измерение из байтов и времени
    public init(bytes: Int64, timeInterval: TimeInterval) {
        let bitsPerSecond = Double(bytes) * Self.bitsInByte / timeInterval
        self.value = bitsPerSecond
        self.unit = .bitsPerSecond
    }
    
    /// Скорость в Mbps для унифицированных сравнений
    public var megabitsPerSecond: Double {
        let bpsValue = value * unit.conversionFactor
        return bpsValue / BandwidthUnit.megabitsPerSecond.conversionFactor
    }
    
    /// Автоматически форматированная версия с подходящими единицами
    public var formatted: BandwidthMeasurement {
        var currentValue = value * unit.conversionFactor
        var targetUnit = BandwidthUnit.bitsPerSecond
        
        for unit in BandwidthUnit.allCases.dropFirst() {
            if currentValue >= Self.unitStepSize {
                currentValue /= Self.unitStepSize
                targetUnit = unit
            } else {
                break
            }
        }
        
        return BandwidthMeasurement(value: currentValue, unit: targetUnit)
    }
    
    public var description: String {
        return String(format: "%.1f %@", formatted.value, formatted.unit.symbol)
    }
    
    // MARK: - Comparable
    
    public static func < (lhs: BandwidthMeasurement, rhs: BandwidthMeasurement) -> Bool {
        return lhs.megabitsPerSecond < rhs.megabitsPerSecond
    }
    
    public static func == (lhs: BandwidthMeasurement, rhs: BandwidthMeasurement) -> Bool {
        return abs(lhs.megabitsPerSecond - rhs.megabitsPerSecond) < 0.001
    }
}

// MARK: - Convenience Extensions

public extension BandwidthMeasurement {
    static var zero: BandwidthMeasurement {
        return BandwidthMeasurement(value: 0, unit: .bitsPerSecond)
    }
    
    /// Проверяет, является ли измерение разумным (не слишком высоким)
    func isReasonable(maxMbps: Double = 5000.0) -> Bool {
        return megabitsPerSecond <= maxMbps
    }
}
