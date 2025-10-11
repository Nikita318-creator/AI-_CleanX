import SwiftUI
import Combine
import os.log

// MARK: - Модель данных для скорости (совместимость)
struct SpeedTestSpeed {
    let mBitPs: Double
    
    init(mBitPs: Double) {
        self.mBitPs = mBitPs
    }
    
    init(from bandwidthMeasurement: BandwidthMeasurement) {
        self.mBitPs = bandwidthMeasurement.megabitsPerSecond
    }
}

enum SpeedometerViewLook {
    case idle
    case aboutToDownload
    case download
    case aboutToUpload
    case upload
    case finishing
    case restart
}

enum SpeedUnitType: String, CaseIterable {
    case megabit = "Mbps"
    case megabyte = "MB/s"
}

// Расширение для SpeedTestSpeed, аналогичное вашему примеру
extension SpeedTestSpeed {
    static let zero = SpeedTestSpeed(mBitPs: 0)
    
    var mBytePs: Double {
        mBitPs / 8
    }
    
    func value(by type: SpeedUnitType) -> Double {
        switch type {
        case .megabit:
            return self.mBitPs
        case .megabyte:
            return self.mBytePs
        }
    }
    
    func asTitle(type: SpeedUnitType) -> String {
        let value = self.value(by: type)
        return "\(round(value * 100)/100)"
    }
}

// MARK: - ViewModel для управления состоянием
@MainActor
final class SpeedometerViewModel: ObservableObject {
    @Published var speed: Double = 0.0
    @Published var look: SpeedometerViewLook = .idle
    @Published var latency: String = "0 ms"
    @Published var ip: String? = nil
    @Published var downloadSpeed: Double = 0.0
    @Published var uploadSpeed: Double = 0.0
    @Published var unitType: SpeedUnitType = .megabit
    @Published var isTestInProgress = false
    @Published var testPhase: BandwidthTestPhase = .idle
    @Published var finalDownloadSpeed: Double = 0.0
    @Published var finalUploadSpeed: Double = 0.0
    @Published var serverInfo: String = "Tap to start the test"
    @Published var errorMessage: String?
    
    // Новый сервис
    private let bandwidthCoordinator = BandwidthAnalysisCoordinator()
    private let oldSpeedTestService = SpeedTestService() // Для обратной совместимости
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.cleanme.speedtest", category: "SpeedometerViewModel")
    
    // MARK: - Test Phases
    enum BandwidthTestPhase: Equatable {
        case idle
        case findingServer
        case measuringLatency
        case downloadTest
        case uploadTest
        case completed
        case error(String)
        
        var description: String {
            switch self {
            case .idle:
                return "Ready for testing"
            case .findingServer:
                return "Finding the optimal server..."
            case .measuringLatency:
                return "Measuring latency..."
            case .downloadTest:
                return "Download test..."
            case .uploadTest:
                return "Upload test..."
            case .completed:
                return "Test completed"
            case .error(let message):
                return "Error: \(message)"
            }
        }
        
        var isActive: Bool {
            switch self {
            case .idle, .completed, .error:
                return false
            default:
                return true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Преобразует BandwidthTestPhase в GaugePhase для отображения
    var gaugePhase: GaugePhase {
        switch testPhase {
        case .idle:
            return .idle
        case .findingServer:
            return .findingServer
        case .measuringLatency:
            return .measuringLatency
        case .downloadTest:
            return .download
        case .uploadTest:
            return .upload
        case .completed:
            return .completed
        case .error(_):
            return .idle
        }
    }
    
    init() {
        logger.info("🚀 SpeedometerViewModel: Initialization started")
        setupBindings()
        logger.info("✅ SpeedometerViewModel: Initialization completed")
    }
    
    // MARK: - Setup bindings
    private func setupBindings() {
        logger.info("🔧 SpeedometerViewModel: Setting up bindings...")
        
        // Binding to the old service for simulation (currently used for UI)
        oldSpeedTestService.speedPublisher
            .map { $0.mBitPs }
            .sink { [weak self] newSpeed in
                self?.logger.debug("📊 Old service: speed = \(newSpeed) Mbps")
                self?.speed = newSpeed
            }
            .store(in: &cancellables)
        
        // Binding to the new service for real tests
        bandwidthCoordinator.$currentHost
            .sink { [weak self] host in
                if let host = host {
                    self?.logger.info("🌐 Host found: \(host.name), \(host.country)")
                    self?.serverInfo = "\(host.name), \(host.country)"
                    self?.testPhase = .measuringLatency
                } else {
                    self?.logger.debug("❌ Host not found or reset")
                }
            }
            .store(in: &cancellables)
        
        bandwidthCoordinator.$currentLatency
            .sink { [weak self] latency in
                if let latency = latency {
                    self?.logger.info("⚡ Ping: \(latency) ms")
                    self?.latency = "\(latency) ms"
                } else {
                    self?.logger.debug("❌ Ping not received or reset")
                }
            }
            .store(in: &cancellables)
        
        bandwidthCoordinator.$currentDownloadSpeed
            .sink { [weak self] downloadSpeed in
                if let downloadSpeed = downloadSpeed {
                    self?.logger.info("⬇️ Download speed: \(downloadSpeed.megabitsPerSecond) Mbps")
                    self?.downloadSpeed = downloadSpeed.megabitsPerSecond
                    self?.speed = downloadSpeed.megabitsPerSecond
                    self?.testPhase = .downloadTest
                    self?.look = .download
                } else {
                    self?.logger.debug("❌ Download speed not received or reset")
                }
            }
            .store(in: &cancellables)
        
        bandwidthCoordinator.$currentUploadSpeed
            .sink { [weak self] uploadSpeed in
                if let uploadSpeed = uploadSpeed {
                    self?.logger.info("⬆️ Upload speed: \(uploadSpeed.megabitsPerSecond) Mbps")
                    self?.uploadSpeed = uploadSpeed.megabitsPerSecond
                    self?.speed = uploadSpeed.megabitsPerSecond
                    self?.testPhase = .uploadTest
                    self?.look = .upload
                } else {
                    self?.logger.debug("❌ Upload speed not received or reset")
                }
            }
            .store(in: &cancellables)
        
        bandwidthCoordinator.$isTestingInProgress
            .sink { [weak self] isTestingInProgress in
                self?.logger.info("🔄 Testing in progress: \(isTestingInProgress)")
                self?.isTestInProgress = isTestingInProgress
                
                if isTestingInProgress {
                    self?.logger.info("🟡 Starting test - finding server")
                    self?.testPhase = .findingServer
                    self?.look = .aboutToDownload
                    self?.errorMessage = nil
                } else {
                    self?.logger.info("🔴 Test finished")
                    if self?.testPhase != .error("") {
                        self?.testPhase = .idle
                        self?.look = .finishing
                        // Save final results
                        self?.finalDownloadSpeed = self?.downloadSpeed ?? 0
                        self?.finalUploadSpeed = self?.uploadSpeed ?? 0
                        self?.logger.info("✅ Final results: Download=\(self?.finalDownloadSpeed ?? 0) Upload=\(self?.finalUploadSpeed ?? 0)")
                    }
                }
            }
            .store(in: &cancellables)
        
        bandwidthCoordinator.$isUploadPhase
            .sink { [weak self] isUploadPhase in
                self?.logger.info("📤 Upload phase: \(isUploadPhase)")
                if isUploadPhase {
                    self?.testPhase = .uploadTest
                    self?.look = .upload
                }
            }
            .store(in: &cancellables)
        
        logger.info("✅ Bindings successfully set up")
    }
    
    // MARK: - Public methods
    
    /// Start a simulated test (for UI demonstration)
    func startSpeedTest() {
        oldSpeedTestService.startDownloadTest()
        look = .download
    }
    
    /// Stop the simulated test
    func stopSpeedTest() {
        oldSpeedTestService.stopTest()
        look = .idle
    }
    
    /// Start a real speed test
    func startRealSpeedTest() {
        logger.info("🚀 STARTING REAL SPEED TEST")
        logger.info("📊 Current state before start:")
        logger.info("   - testPhase: \(String(describing: self.testPhase))")
        logger.info("   - isTestInProgress: \(self.isTestInProgress)")
        
        resetTestData()
        testPhase = .findingServer
        look = .aboutToDownload
        
        logger.info("🔧 Launching BandwidthAnalysisCoordinator...")
        Task {
            logger.info("⚡ Calling startFullBandwidthTest()")
            bandwidthCoordinator.startFullBandwidthTest()
            logger.info("✅ startFullBandwidthTest() called")
        }
    }
    
    /// Reset test data
    func resetTestData() {
        logger.info("🔄 Resetting test data")
        speed = 0.0
        downloadSpeed = 0.0
        uploadSpeed = 0.0
        finalDownloadSpeed = 0.0
        finalUploadSpeed = 0.0
        testPhase = .idle
        errorMessage = nil
        serverInfo = "Tap to start the test"
        look = .idle
        logger.info("✅ Test data reset")
    }
    
    /// Measure network latency
    func measureLatency() async {
        do {
            try await bandwidthCoordinator.measureNetworkLatency()
        } catch {
            latency = "Error"
        }
    }
    
    /// Update IP info (placeholder)
    func updateIP() {
        self.ip = "192.168.1.1"
    }
    
    // MARK: - Deprecated methods for backward compatibility
    
    @available(*, deprecated, message: "Use startRealSpeedTest() instead")
    func startSpeedTestReal() {
        startRealSpeedTest()
    }
    
    @available(*, deprecated, message: "Use measureLatency() instead")
    func getLatency() -> String {
        return latency
    }
}
