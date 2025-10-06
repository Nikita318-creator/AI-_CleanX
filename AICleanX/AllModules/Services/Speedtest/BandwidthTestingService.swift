import Foundation
import Combine
import os.log

/// Состояния тестирования пропускной способности
public enum BandwidthTestState: Equatable {
    case idle
    case testing
    case successful
    case error(String)
    
    public var localizedDescription: String {
        switch self {
        case .idle:
            return "Готов к тестированию"
        case .testing:
            return "Выполняется тестирование"
        case .successful:
            return "Тестирование завершено успешно"
        case .error(let message):
            return "Ошибка: \(message)"
        }
    }
}

/// Главный сервис для тестирования пропускной способности
@MainActor
public final class BandwidthTestingService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var currentState: BandwidthTestState = .idle
    @Published public private(set) var selectedHost: BandwidthTestHost?
    @Published public private(set) var latencyResult: Int?
    @Published public private(set) var currentDownloadSpeed: BandwidthMeasurement?
    @Published public private(set) var currentUploadSpeed: BandwidthMeasurement?
    @Published public private(set) var isUploading = false
    
    // MARK: - Publishers для событий
    public let hostUpdated = PassthroughSubject<BandwidthTestHost, Never>()
    public let latencyUpdated = PassthroughSubject<Int, Never>()
    public let downloadSpeedUpdated = PassthroughSubject<BandwidthMeasurement, Never>()
    public let uploadSpeedUpdated = PassthroughSubject<BandwidthMeasurement, Never>()
    public let downloadFinished = PassthroughSubject<BandwidthMeasurement?, Never>()
    public let uploadFinished = PassthroughSubject<BandwidthMeasurement?, Never>()
    
    // MARK: - Private Properties
    private let bandwidthTester = NetworkBandwidthTester()
    private let speedLimitMbps: Double = 5000.0
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.cleanme.speedtest", category: "BandwidthTestingService")
    
    // MARK: - Singleton
    public static let shared = BandwidthTestingService()
    
    private init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Получить информацию о сотовом операторе
    public var carrierInformation: [CellularNetworkInfo] {
        return CellularInfoProvider().getCellularInformation()
    }
    
    /// Сброс данных перед новым тестированием
    public func resetTestData() {
        currentState = .idle
        selectedHost = nil
        latencyResult = nil
        currentDownloadSpeed = nil
        currentUploadSpeed = nil
        isUploading = false
        cancellables.removeAll()
    }
    
    /// Запуск полного теста пропускной способности
    public func startFullBandwidthTest() async {
        guard currentState != .testing else {
            return
        }
        
        resetTestData()
        currentState = .testing
        
        do {
            // 1. Найти лучший хост
            let hostAndLatency = try await findOptimalHost()
            
            await MainActor.run {
                self.selectedHost = hostAndLatency.0
                self.latencyResult = hostAndLatency.1
                self.hostUpdated.send(hostAndLatency.0)
                self.latencyUpdated.send(hostAndLatency.1)
            }
            
            // 2. Тест загрузки
            let downloadResult = try await performDownloadTest(host: hostAndLatency.0)
            
            await MainActor.run {
                self.downloadFinished.send(downloadResult)
            }
            
            // Небольшая задержка между тестами
            try await Task.sleep(nanoseconds: 450_000_000)
            
            // 3. Тест отправки
            await MainActor.run {
                self.isUploading = true
            }
            
            let uploadResult = try await performUploadTest(host: hostAndLatency.0)
            
            await MainActor.run {
                self.isUploading = false
                self.uploadFinished.send(uploadResult)
                self.currentState = .successful
            }
            
        } catch {
            await MainActor.run {
                self.isUploading = false
                self.currentState = .error(error.localizedDescription)
            }
        }
    }
    
    /// Найти лучший хост для тестирования
    public func findBestHost() async throws -> BandwidthTestHost {
        logger.info("🔍 BandwidthTestingService: ПОИСК ЛУЧШЕГО ХОСТА")
        
        logger.info("⚡ Вызов findOptimalHost()...")
        let hostAndLatency = try await findOptimalHost()
        logger.info("✅ Найден хост: \(hostAndLatency.0.name) с латентностью \(hostAndLatency.1)ms")
        
        await MainActor.run {
            logger.info("📡 Обновление UI данных...")
            self.selectedHost = hostAndLatency.0
            self.latencyResult = hostAndLatency.1
            self.hostUpdated.send(hostAndLatency.0)
            logger.info("✅ UI данные обновлены")
        }
        
        return hostAndLatency.0
    }
    
    /// Измерить задержку для текущего хоста
    public func measureLatency() async throws -> Int {
        logger.info("⚡ BandwidthTestingService: ИЗМЕРЕНИЕ ЗАДЕРЖКИ")
        
        guard let host = selectedHost else {
            logger.error("❌ Хост не выбран для измерения задержки")
            throw BandwidthTestError.hostNotFound
        }
        
        logger.info("📡 Измерение задержки для хоста: \(host.name)")
        return try await withCheckedThrowingContinuation { continuation in
            bandwidthTester.measureLatency(for: host)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.logger.error("❌ Ошибка измерения задержки: \(error)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { [weak self] latency in
                        self?.logger.info("✅ Задержка измерена: \(latency)ms")
                        Task { @MainActor in
                            self?.latencyResult = latency
                            self?.latencyUpdated.send(latency)
                        }
                        continuation.resume(returning: latency)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        bandwidthTester.$currentPhase
            .sink { [weak self] phase in
                Task { @MainActor in
                    switch phase {
                    case .idle, .completed:
                        if self?.currentState == .testing {
                            self?.currentState = .successful
                        }
                    case .failed(let error):
                        self?.currentState = .error(error.localizedDescription)
                    default:
                        break
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func findOptimalHost() async throws -> (BandwidthTestHost, Int) {
        logger.info("🔍 findOptimalHost: ПОИСК ОПТИМАЛЬНОГО ХОСТА")
        
        return try await withCheckedThrowingContinuation { continuation in
            logger.info("⚡ Вызов bandwidthTester.findOptimalHost()...")
            bandwidthTester.findOptimalHost()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.logger.error("❌ Ошибка поиска хоста: \(error)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { hostAndLatency in
                        self.logger.info("✅ Найден оптимальный хост: \(hostAndLatency.0.name) с задержкой \(hostAndLatency.1)ms")
                        continuation.resume(returning: hostAndLatency)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func performDownloadTest(host: BandwidthTestHost) async throws -> BandwidthMeasurement {
        let downloadService = DownloadBandwidthService()
        
        return try await withCheckedThrowingContinuation { continuation in
            downloadService.performTest(
                to: host.url,
                dataSize: 80_000_000,
                timeout: 60.0
            ) { [weak self] measurements in
                Task { @MainActor in
                    if measurements.average.isReasonable(maxMbps: self?.speedLimitMbps ?? 5000.0) {
                        self?.currentDownloadSpeed = measurements.average
                        self?.downloadSpeedUpdated.send(measurements.average)
                    }
                }
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { result in
                    continuation.resume(returning: result)
                }
            )
            .store(in: &cancellables)
        }
    }
    
    private func performUploadTest(host: BandwidthTestHost) async throws -> BandwidthMeasurement {
        let uploadService = UploadBandwidthService()
        
        return try await withCheckedThrowingContinuation { continuation in
            uploadService.performTest(
                to: host.url,
                dataSize: 80_000_000,
                timeout: 60.0
            ) { [weak self] measurements in
                Task { @MainActor in
                    if measurements.average.isReasonable(maxMbps: self?.speedLimitMbps ?? 5000.0) {
                        self?.currentUploadSpeed = measurements.average
                        self?.uploadSpeedUpdated.send(measurements.average)
                    }
                }
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { result in
                    continuation.resume(returning: result)
                }
            )
            .store(in: &cancellables)
        }
    }
}

// MARK: - Compatibility Extensions

public extension BandwidthTestingService {
    /// Устаревший метод для обратной совместимости
    @available(*, deprecated, message: "Используйте findBestHost() с async/await")
    func findBestHostForTest(
        bestHost: @escaping (BandwidthTestHost) -> Void,
        error: @escaping (String) -> Void
    ) {
        Task {
            do {
                let host = try await findBestHost()
                bestHost(host)
            } catch let fetchError {
                error(fetchError.localizedDescription)
            }
        }
    }
    
    /// Устаревший метод для обратной совместимости
    @available(*, deprecated, message: "Используйте measureLatency() с async/await")
    func makePingTest(
        ping: @escaping (Int) -> Void,
        error: @escaping (String) -> Void
    ) {
        Task {
            do {
                let latency = try await measureLatency()
                ping(latency)
            } catch let fetchError {
                error(fetchError.localizedDescription)
            }
        }
    }
}
