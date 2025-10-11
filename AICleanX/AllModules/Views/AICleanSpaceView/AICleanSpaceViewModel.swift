import Foundation
import SwiftUI
import Combine

@MainActor
final class AICleanSpaceViewModel: ObservableObject {
    enum TabType: String, CaseIterable {
        case clean = "Clean"
        case dashboard = "Dashboard"
        case safeFolder = "Safe Folder"
    }
    
    // MARK: - Published Properties
    @Published var mainScanState: ScanningState = .idle
    @Published var scanningProgressValue: Double = 0.0
    @Published var currentSelectedTab: TabType = .clean {
        didSet {
            AnalyticService.shared.logEvent(name: "currentSelectedTab: \(currentSelectedTab)", properties: ["":""])
        }
    }
    
    // MARK: - Media Cleaner Properties
    @Published var progress: AICleanServiceProgress = AICleanServiceProgress(type: .image(.similar), index: 0, value: 0, isFinished: false)
    @Published var counts: AICleanServiceCounts<Int> = AICleanServiceCounts<Int>()
    @Published var megabytes: AICleanServiceCounts<Double> = AICleanServiceCounts<Double>()
    @Published var previews: AICleanServicePreviews = AICleanServicePreviews(_similar: nil, _duplicates: nil, _blurred: nil, _screenshots: nil, _videos: nil)
    @Published var mediaWasDeleted: AICleanServiceType = .image(.similar)
    
    // Individual preview properties
    @Published var similarPreview: UIImage? = nil
    @Published var blurredPreview: UIImage? = nil
    @Published var duplicatesPreview: UIImage? = nil
    @Published var screenshotsPreview: UIImage? = nil
    @Published var videosPreview: UIImage? = nil
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var scanTimer: Timer?
    private lazy var mediaCleanerService = AIMainCleanService.shared
    
    // MARK: - Initialization
    
    init() {}
    
    func setupBindings() {
        // Subscribe to progress updates
        mediaCleanerService.progressPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.progress, on: self)
            .store(in: &cancellables)
        
        // Subscribe to counts updates
        mediaCleanerService.countsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.counts, on: self)
            .store(in: &cancellables)
        
        // Subscribe to megabytes updates
        mediaCleanerService.megabytesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.megabytes, on: self)
            .store(in: &cancellables)
        
        // Subscribe to previews updates
        mediaCleanerService.previewsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.previews, on: self)
            .store(in: &cancellables)
        
        // Subscribe to media deletion events
        mediaCleanerService.mediaWasDeletedPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.mediaWasDeleted, on: self)
            .store(in: &cancellables)
        
        // Subscribe to individual preview updates
        mediaCleanerService.similarPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.similarPreview, on: self)
            .store(in: &cancellables)
        
        mediaCleanerService.blurredPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.blurredPreview, on: self)
            .store(in: &cancellables)
        
        mediaCleanerService.duplicatesPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.duplicatesPreview, on: self)
            .store(in: &cancellables)
        
        mediaCleanerService.screenshotsPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.screenshotsPreview, on: self)
            .store(in: &cancellables)
        
        mediaCleanerService.videosPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.videosPreview, on: self)
            .store(in: &cancellables)
    }
}
