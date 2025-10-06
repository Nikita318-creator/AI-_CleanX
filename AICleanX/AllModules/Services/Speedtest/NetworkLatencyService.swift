import Foundation
import Combine

/// Сервис для измерения задержки сети
public final class NetworkLatencyService: NetworkLatencyMeasuring {
    
    public init() {}
    
    public func measureLatency(to url: URL, timeout: TimeInterval) -> AnyPublisher<Int, BandwidthTestError> {
        return url.measureLatency(timeout: timeout)
            .mapError { networkLatencyError in
                switch networkLatencyError {
                case .requestFailed:
                    return BandwidthTestError.requestFailed
                case .timeout:
                    return BandwidthTestError.timeout
                case .invalidResponse:
                    return BandwidthTestError.requestFailed
                }
            }
            .eraseToAnyPublisher()
    }
}
