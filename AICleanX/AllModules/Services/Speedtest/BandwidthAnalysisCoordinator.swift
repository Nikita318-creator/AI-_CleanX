import Foundation
import Combine
import os.log

/// Координатор для анализа пропускной способности сети
@MainActor
public final class BandwidthAnalysisCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isTestingInProgress = false
    @Published public private(set) var currentHost: BandwidthTestHost?
    @Published public private(set) var currentLatency: Int?
    @Published public private(set) var currentDownloadSpeed: BandwidthMeasurement?
    @Published public private(set) var currentUploadSpeed: BandwidthMeasurement?
    @Published public private(set) var isUploadPhase = false
    
    // MARK: - Event Publishers
    public let hostUpdated = PassthroughSubject<BandwidthTestHost, Never>()
    public let latencyUpdated = PassthroughSubject<Int, Never>()
    public let downloadSpeedUpdated = PassthroughSubject<BandwidthMeasurement, Never>()
    public let uploadSpeedUpdated = PassthroughSubject<BandwidthMeasurement, Never>()
    public let downloadCompleted = PassthroughSubject<BandwidthMeasurement?, Never>()
    public let uploadCompleted = PassthroughSubject<BandwidthMeasurement?, Never>()
    public let testCompleted = PassthroughSubject<Void, Never>()
    
    // MARK: - Private Properties
    private let bandwidthService = BandwidthTestingService.shared
    private let cellularInfoProvider = CellularInfoProvider()
    private var cancellables = Set<AnyCancellable>()
    private let speedFilterLimit: Double = 5000.0
    private let logger = Logger(subsystem: "com.cleanme.speedtest", category: "BandwidthAnalysis")
    
    public init() {
        setupEventBindings()
    }
    
    // MARK: - Public Properties
    
    /// Информация о сотовом операторе
    public var carrierInformation: [CellularNetworkInfo] {
        return cellularInfoProvider.getCellularInformation()
    }
    
    // MARK: - Public Methods
    
    /// Запуск полного теста пропускной способности
    public func startFullBandwidthTest() {
        logger.info("🚀 BandwidthAnalysisCoordinator: ЗАПУСК ПОЛНОГО ТЕСТА")
        logger.info("📊 Текущее состояние:")
        logger.info("   - isTestingInProgress: \(self.isTestingInProgress)")
        logger.info("   - currentHost: \(String(describing: self.currentHost))")
        
        guard !isTestingInProgress else {
            logger.error("❌ Bandwidth Test: тестирование уже выполняется")
            return
        }
        
        logger.info("🔄 Сброс данных и начало теста...")
        resetTestData()
        isTestingInProgress = true
        
        logger.info("⚡ Запуск Task для performSequentialTests")
        Task {
            do {
                logger.info("🔧 Начало performSequentialTests()")
                try await performSequentialTests()
                logger.info("✅ performSequentialTests() завершен успешно")
                testCompleted.send()
            } catch {
                logger.error("❌ Bandwidth Test Error: \(error.localizedDescription)")
            }
            
            logger.info("🔴 Установка isTestingInProgress = false")
            isTestingInProgress = false
        }
    }
    
    /// Найти оптимальный хост для тестирования
    public func findOptimalHost() async throws {
        isTestingInProgress = true
        defer { isTestingInProgress = false }
        
        let host = try await bandwidthService.findBestHost()
        
        currentHost = host
        hostUpdated.send(host)
        
        logger.debug("Optimal Host Found: \(host.name)")
    }
    
    /// Измерить задержку сети
    public func measureNetworkLatency() async throws {
        isTestingInProgress = true
        defer { isTestingInProgress = false }
        
        let latency = try await bandwidthService.measureLatency()
        
        currentLatency = latency
        latencyUpdated.send(latency)
        
        logger.debug("Network Latency: \(latency)ms")
    }
    
    /// Выполнить тест скорости загрузки
    public func performDownloadSpeedTest() async throws -> BandwidthMeasurement? {
        guard let host = currentHost else {
            throw BandwidthTestError.hostNotFound
        }
        
        isTestingInProgress = true
        defer { isTestingInProgress = false }
        
        let downloadService = DownloadBandwidthService()
        
        return try await withCheckedThrowingContinuation { continuation in
            downloadService.performTest(
                to: host.url,
                dataSize: 80_000_000,
                timeout: 60.0
            ) { [weak self] measurements in
                Task { @MainActor in
                    if measurements.average.isReasonable(maxMbps: self?.speedFilterLimit ?? 5000.0) {
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
                receiveValue: { [weak self] result in
                    Task { @MainActor in
                        if result.isReasonable(maxMbps: self?.speedFilterLimit ?? 5000.0) {
                            self?.currentDownloadSpeed = result
                            self?.downloadSpeedUpdated.send(result)
                        }
                        self?.downloadCompleted.send(result)
                    }
                    continuation.resume(returning: result)
                }
            )
            .store(in: &cancellables)
        }
    }
    
    /// Выполнить тест скорости отправки
    public func performUploadSpeedTest() async throws -> BandwidthMeasurement? {
        guard let host = currentHost else {
            throw BandwidthTestError.hostNotFound
        }
        
        isTestingInProgress = true
        isUploadPhase = true
        defer { 
            isTestingInProgress = false
            isUploadPhase = false
        }
        
        let uploadService = UploadBandwidthService()
        
        return try await withCheckedThrowingContinuation { continuation in
            uploadService.performTest(
                to: host.url,
                dataSize: 80_000_000,
                timeout: 60.0
            ) { [weak self] measurements in
                Task { @MainActor in
                    if measurements.average.isReasonable(maxMbps: self?.speedFilterLimit ?? 5000.0) {
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
                receiveValue: { [weak self] result in
                    Task { @MainActor in
                        if result.isReasonable(maxMbps: self?.speedFilterLimit ?? 5000.0) {
                            self?.currentUploadSpeed = result
                            self?.uploadSpeedUpdated.send(result)
                        }
                        self?.uploadCompleted.send(result)
                    }
                    continuation.resume(returning: result)
                }
            )
            .store(in: &cancellables)
        }
    }
    
    /// Сброс данных тестирования
    public func resetTestData() {
        currentHost = nil
        currentLatency = nil
        currentDownloadSpeed = nil
        currentUploadSpeed = nil
        isUploadPhase = false
        cancellables.removeAll()
        
        bandwidthService.resetTestData()
    }
    
    // MARK: - Private Methods
    
    private func setupEventBindings() {
        // Привязка событий от BandwidthTestingService
        bandwidthService.hostUpdated
            .sink { [weak self] host in
                self?.currentHost = host
                self?.hostUpdated.send(host)
            }
            .store(in: &cancellables)
        
        bandwidthService.latencyUpdated
            .sink { [weak self] latency in
                self?.currentLatency = latency
                self?.latencyUpdated.send(latency)
            }
            .store(in: &cancellables)
        
        bandwidthService.downloadSpeedUpdated
            .sink { [weak self] speed in
                self?.currentDownloadSpeed = speed
                self?.downloadSpeedUpdated.send(speed)
            }
            .store(in: &cancellables)
        
        bandwidthService.uploadSpeedUpdated
            .sink { [weak self] speed in
                self?.currentUploadSpeed = speed
                self?.uploadSpeedUpdated.send(speed)
            }
            .store(in: &cancellables)
        
        bandwidthService.$isUploading
            .sink { [weak self] isUploading in
                self?.isUploadPhase = isUploading
            }
            .store(in: &cancellables)
    }
    
    private func performSequentialTests() async throws {
        logger.info("🔄 performSequentialTests: НАЧАЛО ПОСЛЕДОВАТЕЛЬНЫХ ТЕСТОВ")
        
        // 1. Поиск оптимального хоста
        logger.info("1️⃣ Этап 1: Поиск оптимального хоста...")
        try await findOptimalHost()
        logger.info("✅ Этап 1 завершен: Хост найден")
        
        // 2. Измерение задержки
        logger.info("2️⃣ Этап 2: Измерение латентности...")
        try await measureNetworkLatency()
        logger.info("✅ Этап 2 завершен: Латентность измерена")
        
        // 3. Тест загрузки
        logger.info("3️⃣ Этап 3: Тест скорости загрузки...")
        let downloadResult = try await performDownloadSpeedTest()
        if let downloadResult = downloadResult {
            logger.info("✅ Этап 3 завершен: Скорость загрузки = \(downloadResult.megabitsPerSecond) Mbps")
        } else {
            logger.warning("⚠️ Этап 3: Результат загрузки = nil")
        }
        
        // Небольшая задержка между тестами
        logger.info("⏱️ Пауза между тестами (450ms)")
        try await Task.sleep(nanoseconds: 450_000_000)
        
        // 4. Тест отправки
        logger.info("4️⃣ Этап 4: Тест скорости выгрузки...")
        let uploadResult = try await performUploadSpeedTest()
        if let uploadResult = uploadResult {
            logger.info("✅ Этап 4 завершен: Скорость выгрузки = \(uploadResult.megabitsPerSecond) Mbps")
        } else {
            logger.warning("⚠️ Этап 4: Результат выгрузки = nil")
        }
        
        logger.info("🎉 performSequentialTests: ВСЕ ЭТАПЫ ЗАВЕРШЕНЫ")
    }
}

// MARK: - Compatibility Layer для старого API

public extension BandwidthAnalysisCoordinator {
    
    /// Устаревший метод для обратной совместимости с callback API
    @available(*, deprecated, message: "Используйте findOptimalHost() с async/await")
    func findHost(completion: @escaping (BandwidthTestHost) -> Void) {
        Task {
            do {
                try await findOptimalHost()
                if let host = currentHost {
                    completion(host)
                }
            } catch {
                logger.error("Find Host Error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Устаревший метод для обратной совместимости с callback API
    @available(*, deprecated, message: "Используйте measureNetworkLatency() с async/await")
    func checkPing(completion: @escaping (Int) -> Void) {
        Task {
            do {
                try await measureNetworkLatency()
                if let latency = currentLatency {
                    completion(latency)
                }
            } catch {
                logger.error("Check Ping Error: \(error.localizedDescription)")
            }
        }
    }
}
