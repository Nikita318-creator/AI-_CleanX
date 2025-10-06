import Foundation
import Combine

/// Сервис для тестирования скорости отправки
public final class UploadBandwidthService: NSObject, BandwidthTesting {
    private var startTime: Date?
    private var previousTime: Date?
    private var progressSubject = PassthroughSubject<CurrentMeasurements, Never>()
    private var resultSubject = PassthroughSubject<BandwidthMeasurement, BandwidthTestError>()
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
    }
    
    public func performTest(
        to url: URL,
        dataSize: Int,
        timeout: TimeInterval,
        progressHandler: @escaping (CurrentMeasurements) -> Void
    ) -> AnyPublisher<BandwidthMeasurement, BandwidthTestError> {
        
        let sessionConfig = createSessionConfiguration(timeout: timeout)
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: .main)
        
        progressSubject
            .sink(receiveValue: progressHandler)
            .store(in: &cancellables)
        
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Content-Type": "application/octet-stream",
            "Accept-Encoding": "gzip, deflate",
            "Content-Length": "\(dataSize)",
            "Connection": "keep-alive"
        ]
        
        let uploadData = Data(count: dataSize)
        let uploadTask = session.uploadTask(with: request, from: uploadData)
        uploadTask.resume()
        
        return resultSubject
            .handleEvents(receiveCancel: {
                uploadTask.cancel()
                session.invalidateAndCancel()
            })
            .eraseToAnyPublisher()
    }
    
    private func createSessionConfiguration(timeout: TimeInterval) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return config
    }
    
    private func calculateBandwidth(bytes: Int64, timeInterval: TimeInterval) -> BandwidthMeasurement {
        return BandwidthMeasurement(bytes: bytes, timeInterval: timeInterval).formatted
    }
}

// MARK: - URLSessionDataDelegate

extension UploadBandwidthService: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        
        guard let startTime = startTime else {
            resultSubject.send(completion: .failure(.unknownError))
            completionHandler(.cancel)
            return
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let result = calculateBandwidth(bytes: dataTask.countOfBytesSent, timeInterval: totalTime)
        
        resultSubject.send(result)
        resultSubject.send(completion: .finished)
        
        completionHandler(.cancel)
        
        // Очистка
        session.invalidateAndCancel()
        cancellables.removeAll()
    }
}

// MARK: - URLSessionTaskDelegate

extension UploadBandwidthService: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        let currentTime = Date()
        
        if startTime == nil {
            startTime = currentTime
            previousTime = currentTime
            return
        }
        
        guard let startTime = startTime, let previousTime = previousTime else { return }
        
        let currentSpeed = calculateBandwidth(
            bytes: bytesSent,
            timeInterval: currentTime.timeIntervalSince(previousTime)
        )
        
        let averageSpeed = calculateBandwidth(
            bytes: totalBytesSent,
            timeInterval: currentTime.timeIntervalSince(startTime)
        )
        
        self.previousTime = currentTime
        
        let measurements = (current: currentSpeed, average: averageSpeed)
        progressSubject.send(measurements)
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            print(error)
            resultSubject.send(completion: .failure(.requestFailed))
        }
        cancellables.removeAll()
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print(error)
            resultSubject.send(completion: .failure(.requestFailed))
            session.invalidateAndCancel()
            cancellables.removeAll()
        }
    }
}
