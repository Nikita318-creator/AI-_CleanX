import Foundation
import Combine
import os.log

/// Основной класс для тестирования пропускной способности сети
public final class NetworkBandwidthTester: ObservableObject {
    
    // MARK: - Services
    private let hostProvider: BandwidthHostProviding
    private let latencyService: NetworkLatencyMeasuring
    private let downloadService = DownloadBandwidthService()
    private let uploadService = UploadBandwidthService()
    
    // MARK: - Published Properties
    @Published public private(set) var isTestingInProgress = false
    @Published public private(set) var currentPhase: TestPhase = .idle
    @Published public private(set) var selectedHost: BandwidthTestHost?
    @Published public private(set) var latencyResult: Int?
    @Published public private(set) var downloadResult: BandwidthMeasurement?
    @Published public private(set) var uploadResult: BandwidthMeasurement?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.cleanme.speedtest", category: "NetworkBandwidthTester")
    
    // MARK: - Test Phases
    public enum TestPhase {
        case idle
        case findingHost
        case measuringLatency
        case testingDownload
        case testingUpload
        case completed
        case failed(BandwidthTestError)
        
        public var description: String {
            switch self {
            case .idle:
                return "Готов к тестированию"
            case .findingHost:
                return "Поиск оптимального сервера"
            case .measuringLatency:
                return "Измерение задержки"
            case .testingDownload:
                return "Тест загрузки"
            case .testingUpload:
                return "Тест отправки"
            case .completed:
                return "Тестирование завершено"
            case .failed(let error):
                return "Ошибка: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Initialization
    public init(hostProvider: BandwidthHostProviding? = nil, latencyService: NetworkLatencyMeasuring? = nil) {
        self.hostProvider = hostProvider ?? BandwidthHostProvider()
        self.latencyService = latencyService ?? NetworkLatencyService()
    }
    
    // MARK: - Public Methods
    
    /// Найти доступные хосты
    public func findAvailableHosts(timeout: TimeInterval = 30.0) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError> {
        return hostProvider.fetchHosts(timeout: timeout)
    }
    
    /// Найти лучший хост по задержке
    public func findOptimalHost(maxHosts: Int = 10, timeout: TimeInterval = 30.0) -> AnyPublisher<(BandwidthTestHost, Int), BandwidthTestError> {
        logger.info("🔍 NetworkBandwidthTester: ПОИСК ОПТИМАЛЬНОГО ХОСТА")
        logger.info("📊 Параметры: maxHosts=\(maxHosts), timeout=\(timeout)")
        
        return hostProvider.fetchHosts(maxCount: maxHosts, timeout: timeout)
            .handleEvents(receiveOutput: { [weak self] hosts in
                self?.logger.info("📡 Получено \(hosts.count) хостов от провайдера")
            })
            .flatMap { [weak self] hosts -> AnyPublisher<(BandwidthTestHost, Int), BandwidthTestError> in
                guard let self = self else {
                    return Fail(error: BandwidthTestError.unknownError).eraseToAnyPublisher()
                }
                self.logger.info("⚡ Начинаем измерение задержки для хостов...")
                return self.measureLatencyForHosts(hosts, timeout: timeout)
            }
            .handleEvents(receiveOutput: { [weak self] (host, latency) in
                self?.logger.info("🎯 Выбран лучший хост: \(host.name) с задержкой \(latency)ms")
            })
            .eraseToAnyPublisher()
    }
    
    /// Измерить задержку для хоста
    public func measureLatency(for host: BandwidthTestHost, timeout: TimeInterval = 10.0) -> AnyPublisher<Int, BandwidthTestError> {
        guard let pingURL = host.pingURL else {
            return Fail(error: BandwidthTestError.requestFailed).eraseToAnyPublisher()
        }
        
        return latencyService.measureLatency(to: pingURL, timeout: timeout)
    }
    
    /// Выполнить полный тест пропускной способности
    public func performFullTest(
        downloadProgressHandler: @escaping (BandwidthMeasurement) -> Void = { _ in },
        uploadProgressHandler: @escaping (BandwidthMeasurement) -> Void = { _ in }
    ) {
        guard !isTestingInProgress else {
            currentPhase = .failed(.testInProgress)
            return
        }
        
        resetTestResults()
        isTestingInProgress = true
        currentPhase = .findingHost
        
        findOptimalHost()
            .flatMap { [weak self] hostAndLatency -> AnyPublisher<BandwidthMeasurement, BandwidthTestError> in
                guard let self = self else {
                    return Fail(error: BandwidthTestError.unknownError).eraseToAnyPublisher()
                }
                
                DispatchQueue.main.async {
                    self.selectedHost = hostAndLatency.0
                    self.latencyResult = hostAndLatency.1
                    self.currentPhase = .testingDownload
                }
                
                return self.downloadService.performTest(
                    to: hostAndLatency.0.url,
                    dataSize: 80_000_000,
                    timeout: 60.0
                ) { measurements in
                    DispatchQueue.main.async {
                        downloadProgressHandler(measurements.average)
                    }
                }
            }
            .delay(for: .milliseconds(450), scheduler: DispatchQueue.main)
            .flatMap { [weak self] downloadResult -> AnyPublisher<BandwidthMeasurement, BandwidthTestError> in
                guard let self = self, let host = self.selectedHost else {
                    return Fail(error: BandwidthTestError.unknownError).eraseToAnyPublisher()
                }
                
                DispatchQueue.main.async {
                    self.downloadResult = downloadResult
                    self.currentPhase = .testingUpload
                }
                
                return self.uploadService.performTest(
                    to: host.url,
                    dataSize: 80_000_000,
                    timeout: 60.0
                ) { measurements in
                    DispatchQueue.main.async {
                        uploadProgressHandler(measurements.average)
                    }
                }
            }
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        switch completion {
                        case .finished:
                            self?.currentPhase = .completed
                        case .failure(let error):
                            self?.currentPhase = .failed(error)
                        }
                        self?.isTestingInProgress = false
                    }
                },
                receiveValue: { [weak self] uploadResult in
                    DispatchQueue.main.async {
                        self?.uploadResult = uploadResult
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Отменить текущий тест
    public func cancelTest() {
        cancellables.removeAll()
        isTestingInProgress = false
        currentPhase = .idle
    }
    
    // MARK: - Private Methods
    
    private func resetTestResults() {
        selectedHost = nil
        latencyResult = nil
        downloadResult = nil
        uploadResult = nil
        currentPhase = .idle
    }
    
    private func measureLatencyForHosts(_ hosts: [BandwidthTestHost], timeout: TimeInterval) -> AnyPublisher<(BandwidthTestHost, Int), BandwidthTestError> {
        let publishers = hosts.compactMap { host -> AnyPublisher<(BandwidthTestHost, Int), BandwidthTestError>? in
            guard let pingURL = host.pingURL else { return nil }
            
            return latencyService.measureLatency(to: pingURL, timeout: timeout)
                .map { latency in (host, latency) }
                .catch { _ in Empty<(BandwidthTestHost, Int), BandwidthTestError>() }
                .eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .tryMap { results -> (BandwidthTestHost, Int) in
                guard let best = results.min(by: { $0.1 < $1.1 }) else {
                    throw BandwidthTestError.hostNotFound
                }
                return best
            }
            .mapError { error -> BandwidthTestError in
                if let bandwidthError = error as? BandwidthTestError {
                    return bandwidthError
                } else {
                    return .unknownError
                }
            }
            .eraseToAnyPublisher()
    }
}
