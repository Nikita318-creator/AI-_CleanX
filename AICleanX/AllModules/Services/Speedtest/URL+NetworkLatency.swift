import Foundation
import Combine

public enum NetworkLatencyError: Error {
    case requestFailed
    case timeout
    case invalidResponse
    
    public var localizedDescription: String {
        switch self {
        case .requestFailed:
            return "Network request failed"
        case .timeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid response received"
        }
    }
}

extension URL {
    /// Измеряет задержку сети (ping) до указанного URL
    func measureLatency(timeout: TimeInterval = 10.0) -> AnyPublisher<Int, NetworkLatencyError> {
        Future<Int, NetworkLatencyError> { promise in
            let startTime = Date()
            
            var request = URLRequest(url: self, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
            request.httpMethod = "HEAD"
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                let responseTime = Date().timeIntervalSince(startTime)
                
                if error != nil {
                    promise(.failure(.requestFailed))
                    return
                }
                
                guard let response = response, response.isSuccessful else {
                    promise(.failure(.invalidResponse))
                    return
                }
                
                let latencyMs = Int(responseTime * 1000)
                promise(.success(latencyMs))
            }.resume()
        }
        .eraseToAnyPublisher()
    }
    
    /// Устаревший метод для обратной совместимости
    @available(*, deprecated, message: "Используйте measureLatency() с Combine")
    func ping(timeout: TimeInterval, closure: @escaping (Result<Int, NetworkLatencyError>) -> ()) {
        var cancellable: AnyCancellable?
        cancellable = measureLatency(timeout: timeout)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        closure(.failure(error))
                    }
                    cancellable = nil
                    print(cancellable as Any)
                },
                receiveValue: { latency in
                    closure(.success(latency))
                }
            )
    }
}
