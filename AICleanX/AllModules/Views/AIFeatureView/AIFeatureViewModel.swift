import SwiftUI
import Combine

@MainActor
class AIFeatureViewModel: ObservableObject {
    @Published var similarCount = 0
    @Published var blurredCount = 0
    @Published var duplicatesCount = 0
    @Published var screenshotsCount = 0
    
    @Published var similarMegabytes = 0.0
    @Published var blurredMegabytes = 0.0
    @Published var duplicatesMegabytes = 0.0
    @Published var screenshotsMegabytes = 0.0
    
    @Published var similarPreview: UIImage?
    @Published var blurredPreview: UIImage?
    @Published var duplicatesPreview: UIImage?
    @Published var screenshotsPreview: UIImage?
    
    // Swipe results tracking
    @Published var swipeDecisions: [String: AIFeatureSwipeDecision] = [:]
    @Published var totalSwipeDecisionsForDeletion = 0
    
    var hasSwipeResults: Bool {
        let result = totalSwipeDecisionsForDeletion > 0
        return result
    }
    
    var swipeResultsSummary: String {
        let totalSavedInCache = getTotalSavedInCache()
        return "Saved: \(totalSavedInCache), Remove: \(totalSwipeDecisionsForDeletion)"
    }
    
    private let purchaseService = ApphudPurchaseService()

    var hasActiveSubscription: Bool {
        purchaseService.hasActiveSubscription
    }
    
    private let mediaCleanerService = AIMainCleanService.shared
    private let cacheService = AICleanCacheService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        loadExistingSwipeDecisions()
        updateTotalSwipeDecisionsCount()
    }
    
    // MARK: - Public Methods
    
    func getSections(for type: AICleanServiceType) -> [AICleanServiceSection] {
        return mediaCleanerService.getMedia(type)
    }
    
    func processSwipeDecisions(_ decisions: [String: AIFeatureSwipeDecision]) {
        swipeDecisions = decisions
        updateTotalSwipeDecisionsCount()
    }
    
    func getSwipeResultsData() -> AICleanResultSwipeData {
        let allSections = [
            getSections(for: .image(.similar)),
            getSections(for: .image(.blurred)),
            getSections(for: .image(.duplicates)),
            getSections(for: .image(.screenshots))
        ].flatMap { $0 }
        
        var savedPhotos: [String] = []
        var removePhotos: [String] = []
        
        for section in allSections {
            for model in section.models {
                let assetId = model.asset.localIdentifier
                if let cacheDecision = cacheService.getSwipeDecision(id: assetId) {
                    if cacheDecision == true {
                        savedPhotos.append(assetId)
                    } else {
                        removePhotos.append(assetId)
                    }
                }
            }
        }
        
        let data = AICleanResultSwipeData(
            keptCount: savedPhotos.count,
            deletedCount: removePhotos.count,
            keptPhotos: savedPhotos,
            deletedPhotos: removePhotos
        )
        
        return data
    }
    
    func finalizePhotoDeletion(_ photosToDelete: [String]) {
        mediaCleanerService.deleteAssets(localIdentifiers: photosToDelete) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let deletedIdentifiers):
                    self.clearSwipeDecisions(for: deletedIdentifiers)
                    self.updateTotalSwipeDecisionsCount()
                    self.mediaCleanerService.updateCountsAndPreviews()
                case .failure(let error):
                    print("SWIPE:RESULTS - Failed to delete assets: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadExistingSwipeDecisions() {
        let allSections = [
            getSections(for: .image(.similar)),
            getSections(for: .image(.blurred)),
            getSections(for: .image(.duplicates)),
            getSections(for: .image(.screenshots))
        ].flatMap { $0 }
        
        var loadedDecisions: [String: AIFeatureSwipeDecision] = [:]
        
        for section in allSections {
            for model in section.models {
                let assetId = model.asset.localIdentifier
                if let cacheDecision = cacheService.getSwipeDecision(id: assetId) {
                    let photoDecision: AIFeatureSwipeDecision = cacheDecision ? .keep : .delete
                    loadedDecisions[assetId] = photoDecision
                }
            }
        }
        
        swipeDecisions = loadedDecisions
    }
    
    private func clearSwipeDecisions(for deletedIdentifiers: [String]) {
        for identifier in deletedIdentifiers {
            swipeDecisions.removeValue(forKey: identifier)
            cacheService.deleteSwipeDecision(id: identifier)
        }
    }
    
    func getSectionsForAssetIdentifiers(_ assetIdentifiers: [String]) -> [AICleanServiceSection] {
        let identifierSet = Set(assetIdentifiers)
        let allSections = [
            getSections(for: .image(.similar)),
            getSections(for: .image(.blurred)),
            getSections(for: .image(.duplicates)),
            getSections(for: .image(.screenshots))
        ].flatMap { $0 }
        
        let filteredSections = allSections.compactMap { section -> AICleanServiceSection? in
            let filteredModels = section.models.filter { model in
                identifierSet.contains(model.asset.localIdentifier)
            }
            
            guard !filteredModels.isEmpty else { return nil }
            
            return AICleanServiceSection(
                kind: section.kind,
                models: filteredModels
            )
        }
        
        return filteredSections
    }
    
    private func setupBindings() {
        mediaCleanerService.countsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] counts in
                guard let self = self else { return }
                
                self.similarCount = counts.similar
                self.blurredCount = counts.blurred
                self.duplicatesCount = counts.duplicates
                self.screenshotsCount = counts.screenshots
            }
            .store(in: &cancellables)
        
        mediaCleanerService.megabytesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] megabytes in
                guard let self = self else { return }
                
                self.similarMegabytes = megabytes.similar
                self.blurredMegabytes = megabytes.blurred
                self.duplicatesMegabytes = megabytes.duplicates
                self.screenshotsMegabytes = megabytes.screenshots
            }
            .store(in: &cancellables)
        
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
    }
    
    // MARK: - Private Helper Methods
    
    func updateTotalSwipeDecisionsCount() {
        print("UPDATE:COUNT:TEST - updateTotalSwipeDecisionsCount() called")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("UPDATE:COUNT:TEST - self is nil in updateTotalSwipeDecisionsCount")
                return
            }
            print("UPDATE:COUNT:TEST - About to call getTotalSwipeDecisionsForDeletion()")
            let newCount = self.cacheService.getTotalSwipeDecisionsForDeletion()
            print("UPDATE:COUNT:TEST - getTotalSwipeDecisionsForDeletion() returned: \(newCount)")
            print("UPDATE:COUNT:TEST - Current totalSwipeDecisionsForDeletion: \(self.totalSwipeDecisionsForDeletion)")
            
            if self.totalSwipeDecisionsForDeletion != newCount {
                print("UPDATE:COUNT:TEST - Count changed from \(self.totalSwipeDecisionsForDeletion) to \(newCount)")
                self.totalSwipeDecisionsForDeletion = newCount
                print("SWIPE:TOTAL:UPDATE - Updated totalSwipeDecisionsForDeletion to \(newCount)")
                print("UPDATE:COUNT:TEST - Updated @Published totalSwipeDecisionsForDeletion to \(newCount)")
            } else {
                print("UPDATE:COUNT:TEST - Count unchanged: \(newCount)")
            }
        }
    }
    
    private func getTotalSavedInCache() -> Int {
        let allSections = [
            getSections(for: .image(.similar)),
            getSections(for: .image(.blurred)),
            getSections(for: .image(.duplicates)),
            getSections(for: .image(.screenshots))
        ].flatMap { $0 }
        
        var savedCount = 0
        for section in allSections {
            for model in section.models {
                let assetId = model.asset.localIdentifier
                if let cacheDecision = cacheService.getSwipeDecision(id: assetId), cacheDecision == true {
                    savedCount += 1
                }
            }
        }
        
        return savedCount
    }
}
