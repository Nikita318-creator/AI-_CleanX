import Foundation
import Combine

/// Ошибки сетевых операций
public enum BandwidthTestError: Error, LocalizedError {
    case requestFailed
    case wrongContentType
    case invalidJSON
    case timeout
    case hostNotFound
    case testInProgress
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Сетевой запрос не выполнен"
        case .wrongContentType:
            return "Неверный тип контента"
        case .invalidJSON:
            return "Некорректный JSON"
        case .timeout:
            return "Превышено время ожидания"
        case .hostNotFound:
            return "Хост не найден"
        case .testInProgress:
            return "Тест уже выполняется"
        case .unknownError:
            return "Неизвестная ошибка"
        }
    }
}

/// Протокол для получения списка хостов
public protocol BandwidthHostProviding: AnyObject {
    /// Получить все доступные хосты
    func fetchHosts(timeout: TimeInterval) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError>
    
    /// Получить ограниченное количество хостов
    func fetchHosts(maxCount: Int, timeout: TimeInterval) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError>
}

/// Протокол для измерения задержки сети
public protocol NetworkLatencyMeasuring: AnyObject {
    /// Измерить задержку до указанного URL
    func measureLatency(to url: URL, timeout: TimeInterval) -> AnyPublisher<Int, BandwidthTestError>
}

/// Протокол для тестирования пропускной способности
public protocol BandwidthTesting: AnyObject {
    /// Типы текущих измерений в процессе теста
    typealias CurrentMeasurements = (current: BandwidthMeasurement, average: BandwidthMeasurement)
    
    /// Выполнить тест пропускной способности
    func performTest(
        to url: URL,
        dataSize: Int,
        timeout: TimeInterval,
        progressHandler: @escaping (CurrentMeasurements) -> Void
    ) -> AnyPublisher<BandwidthMeasurement, BandwidthTestError>
}

// MARK: - Convenience Extensions

public extension BandwidthHostProviding {
    /// Получить хосты с таймаутом по умолчанию
    func fetchHosts() -> AnyPublisher<[BandwidthTestHost], BandwidthTestError> {
        return fetchHosts(timeout: 30.0)
    }
    
    /// Получить ограниченное количество хостов с таймаутом по умолчанию
    func fetchHosts(maxCount: Int) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError> {
        return fetchHosts(maxCount: maxCount, timeout: 30.0)
    }
}

public extension NetworkLatencyMeasuring {
    /// Измерить задержку с таймаутом по умолчанию
    func measureLatency(to url: URL) -> AnyPublisher<Int, BandwidthTestError> {
        return measureLatency(to: url, timeout: 10.0)
    }
}

public extension BandwidthTesting {
    /// Выполнить тест с параметрами по умолчанию
    func performTest(to url: URL) -> AnyPublisher<BandwidthMeasurement, BandwidthTestError> {
        return performTest(
            to: url,
            dataSize: 80_000_000,
            timeout: 60.0,
            progressHandler: { _ in }
        )
    }
}
