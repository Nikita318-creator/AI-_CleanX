import Foundation
import Combine

/// Сервис для тестирования скорости загрузки
public final class DownloadBandwidthService: NSObject, BandwidthTesting {
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
        
        guard let downloadURL = BandwidthTestURLBuilder(baseURL: url).downloadURL(dataSize: dataSize) else {
            return Fail(error: BandwidthTestError.requestFailed)
                .eraseToAnyPublisher()
        }
        
        let sessionConfig = createSessionConfiguration(timeout: timeout)
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: .main)
        
        progressSubject
            .sink(receiveValue: progressHandler)
            .store(in: &cancellables)
        
        let downloadTask = session.downloadTask(with: downloadURL)
        downloadTask.resume()
        
        return resultSubject
            .handleEvents(receiveCancel: {
                downloadTask.cancel()
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

// MARK: - URLSessionDownloadDelegate

extension DownloadBandwidthService: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let startTime = startTime else {
            resultSubject.send(completion: .failure(.unknownError))
            return
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let result = calculateBandwidth(bytes: downloadTask.countOfBytesReceived, timeInterval: totalTime)
        
        resultSubject.send(result)
        resultSubject.send(completion: .finished)
        
        // Очистка
        session.invalidateAndCancel()
        cancellables.removeAll()
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        let currentTime = Date()
        
        if startTime == nil {
            startTime = currentTime
            previousTime = currentTime
            return
        }
        
        guard let startTime = startTime, let previousTime = previousTime else { return }
        
        let currentSpeed = calculateBandwidth(
            bytes: bytesWritten,
            timeInterval: currentTime.timeIntervalSince(previousTime)
        )
        
        let averageSpeed = calculateBandwidth(
            bytes: totalBytesWritten,
            timeInterval: currentTime.timeIntervalSince(startTime)
        )
        
        self.previousTime = currentTime
        
        let measurements = (current: currentSpeed, average: averageSpeed)
        progressSubject.send(measurements)
    }
}

// MARK: - URLSessionTaskDelegate

extension DownloadBandwidthService: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            resultSubject.send(completion: .failure(.requestFailed))
            print(error)
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
