import Foundation
import Photos
import UIKit
import Combine

final class AIMainCleanService: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = AIMainCleanService(
        photoLibrary: PHPhotoLibrary.shared(),
        imageProcessor: ImageProcessorImpl(),
        imageManager: CachingImageManager(),
        cacheService: AICleanCacheService.shared
    )

    private let imageProcessingQueue = DispatchQueue(label: "imageProcessingQueue", qos: .userInteractive)
    private let blurDetectionQueue = DispatchQueue(label: "blurDetectionQueue", qos: .userInteractive)
    private let duplicateDetectionQueue = DispatchQueue(label: "duplicateDetectionQueue", qos: .userInteractive)
    private let videoScanningQueue = DispatchQueue(label: "videoScanningQueue", qos: .userInteractive)

    private let photoLibrary: PHPhotoLibrary
    private let cachingImageManager: CachingImageManager

    private var imageFetchResult: PHFetchResult<PHAsset>?
    private var videoFetchResult: PHFetchResult<PHAsset>?

    private var similarImages: Set<AICleanServiceModel> = [] {
        didSet {
            counts.set(count: similarImages.count, for: .image(.similar))
            countsSubject.send(counts)
        }
    }
    private var duplicateImages: Set<AICleanServiceModel> = [] {
        didSet {
            counts.set(count: duplicateImages.count, for: .image(.duplicates))
            countsSubject.send(counts)
        }
    }
    private var blurredImages: Set<AICleanServiceModel> = [] {
        didSet {
            counts.set(count: blurredImages.count, for: .image(.blurred))
            countsSubject.send(counts)
        }
    }
    private var screenshotImages: Set<AICleanServiceModel> = [] {
        didSet {
            counts.set(count: screenshotImages.count, for: .image(.screenshots))
            countsSubject.send(counts)
        }
    }
    private var videoAssets: Set<AICleanServiceModel> = [] {
        didSet {
            counts.set(count: videoAssets.count, for: .video)
            countsSubject.send(counts)
        }
    }
    private var audioAssets: Set<AICleanServiceModel> = [] {
        didSet {
            counts.set(count: audioAssets.count, for: .audio)
            countsSubject.send(counts)
        }
    }

    private let imageProgress = AICleanServiceProgress.startImages

    private let similarImagePreview = CurrentValueSubject<UIImage?, Never>(nil)
    private let blurredImagePreview = CurrentValueSubject<UIImage?, Never>(nil)
    private let duplicateImagePreview = CurrentValueSubject<UIImage?, Never>(nil)
    private let screenshotImagePreview = CurrentValueSubject<UIImage?, Never>(nil)
    private let videoPreview = CurrentValueSubject<UIImage?, Never>(nil)

    private let imageProcessor: ImageProcessor
    private let cacheService: AICleanCacheService
    
    private let progressSubject = CurrentValueSubject<AICleanServiceProgress, Never>(
        AICleanServiceProgress(type: .image(.similar), index: 1, value: 0, isFinished: false)
    )
    private let countsSubject = CurrentValueSubject<AICleanServiceCounts<Int>, Never>(
        AICleanServiceCounts<Int>()
    )
    private let megabytesSubject = CurrentValueSubject<AICleanServiceCounts<Double>, Never>(
        AICleanServiceCounts<Double>()
    )
    private let previewsSubject = CurrentValueSubject<AICleanServicePreviews, Never>(
        AICleanServicePreviews(_similar: nil, _duplicates: nil, _blurred: nil, _screenshots: nil, _videos: nil)
    )
    private let mediaWasDeletedSubject = CurrentValueSubject<AICleanServiceType, Never>(
        AICleanServiceType.image(.similar)
    )
    
    var progressPublisher: AnyPublisher<AICleanServiceProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    var countsPublisher: AnyPublisher<AICleanServiceCounts<Int>, Never> {
        countsSubject.eraseToAnyPublisher()
    }
    var megabytesPublisher: AnyPublisher<AICleanServiceCounts<Double>, Never> {
        megabytesSubject.eraseToAnyPublisher()
    }
    var previewsPublisher: AnyPublisher<AICleanServicePreviews, Never> {
        previewsSubject.eraseToAnyPublisher()
    }
    var mediaWasDeletedPublisher: AnyPublisher<AICleanServiceType, Never> {
        mediaWasDeletedSubject.eraseToAnyPublisher()
    }
    
    var similarPreviewPublisher: AnyPublisher<UIImage?, Never> {
        similarImagePreview.eraseToAnyPublisher()
    }
    var blurredPreviewPublisher: AnyPublisher<UIImage?, Never> {
        blurredImagePreview.eraseToAnyPublisher()
    }
    var duplicatesPreviewPublisher: AnyPublisher<UIImage?, Never> {
        duplicateImagePreview.eraseToAnyPublisher()
    }
    var screenshotsPreviewPublisher: AnyPublisher<UIImage?, Never> {
        screenshotImagePreview.eraseToAnyPublisher()
    }
    var videosPreviewPublisher: AnyPublisher<UIImage?, Never> {
        videoPreview.eraseToAnyPublisher()
    }
    
    var progress: AICleanServiceProgress { progressSubject.value }
    var counts: AICleanServiceCounts<Int> { countsSubject.value }
    var megabytes: AICleanServiceCounts<Double> { megabytesSubject.value }
    var previews: AICleanServicePreviews { previewsSubject.value }
    var mediaWasDeleted: AICleanServiceType { mediaWasDeletedSubject.value }
    
    init(
        photoLibrary: PHPhotoLibrary,
        imageProcessor: ImageProcessor,
        imageManager: CachingImageManager,
        cacheService: AICleanCacheService
    ) {
        self.photoLibrary = photoLibrary
        self.imageProcessor = imageProcessor
        self.cachingImageManager = imageManager
        self.cacheService = cacheService
        super.init()
        photoLibrary.register(self)
    }

    deinit {
        photoLibrary.unregisterChangeObserver(self)
    }

    func checkAuthorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            completion(status)
        }
    }

    func scanAllImages() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let imageFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        self.imageFetchResult = imageFetchResult
        let total = imageFetchResult.count
        
        if total == 0 {
            let completedProgress = AICleanServiceProgress(
                type: .image,
                index: 0,
                value: 1.0,
                isFinished: true
            )
            DispatchQueue.main.async {
                self.progressSubject.send(completedProgress)
            }
            return
        }

        let duplicatesSize = CGSize(width: 1, height: 1)
        let duplicatesRequestOptions = PHImageRequestOptions()
        duplicatesRequestOptions.deliveryMode = .fastFormat
        duplicatesRequestOptions.resizeMode = .fast

        var similarPreviewIndexThreshold = 0
        var screenshotPreviewIndexThreshold = 0
        var duplicatesPreviewIndexThreshold = 0
        var blurredPreviewIndexThreshold = 0

        var previousSimilarModel: AICleanServiceModel?
        var previousDuplicateModel: AICleanServiceModel?
        var previousDuplicateImage: UIImage?

        imageProcessingQueue.async {
            imageFetchResult.enumerateObjects { asset, index, _ in
                let newProgress = AICleanServiceProgress(
                    type: .image,
                    index: index,
                    value: Double(index + 1) / Double(total),
                    isFinished: index + 1 == total
                )
                
                DispatchQueue.main.async {
                    self.progressSubject.send(newProgress)
                }
                let commonModel = AICleanServiceModel(imageManager: self.cachingImageManager, asset: asset, index: index)

                // MARK: - Finding duplicates
                if let (isDuplicate, equality) = self.cacheService.getDuplicate(id: commonModel.asset.localIdentifier) {
                    if isDuplicate {
                        commonModel.equality = equality
                        if self.insertDuplicate(commonModel) {
                            self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.duplicates))
                        }
                        if self.duplicateImagePreview.value == nil || index > duplicatesPreviewIndexThreshold || index == total - 1 {
                            duplicatesPreviewIndexThreshold = index + total / 20
                            self.getPhotoPreview(
                                asset,
                                delivery: self.duplicateImagePreview.value == nil ? .opportunistic : .highQualityFormat,
                                resize: .fast
                            ) { image in
                                if let image = image {
                                    self.updatePreview(image: image, for: .image(.duplicates))
                                }
                            }
                        }
                    }
                } else {
                    self.cachingImageManager.requestImage(
                        for: asset,
                        targetSize: duplicatesSize,
                        contentMode: .aspectFill,
                        options: duplicatesRequestOptions
                    ) { image, options in
                        self.duplicateDetectionQueue.async {
                            if let image = image {
                                if
                                    let prevDuplicateModel = previousDuplicateModel,
                                    let prevData = previousDuplicateImage?.pngData(),
                                    let curData = image.pngData(),
                                    prevData == curData
                                {
                                    commonModel.equality = prevDuplicateModel.equality
                                    self.cacheService.setDuplicate(
                                        id: commonModel.asset.localIdentifier,
                                        value: true,
                                        equality: prevDuplicateModel.equality
                                    )
                                    self.cacheService.setDuplicate(
                                        id: prevDuplicateModel.asset.localIdentifier,
                                        value: true,
                                        equality: prevDuplicateModel.equality
                                    )
                                    if self.insertDuplicate(prevDuplicateModel) {
                                        self.addMegabytes(count: prevDuplicateModel.asset.fakeSize, to: .image(.duplicates))
                                    }
                                    if self.insertDuplicate(commonModel) {
                                        self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.duplicates))
                                    }
                                    if self.duplicateImagePreview.value == nil || index > duplicatesPreviewIndexThreshold || index == total - 1 {
                                        duplicatesPreviewIndexThreshold = index + total / 20
                                        self.getPhotoPreview(
                                            asset,
                                            delivery: self.duplicateImagePreview.value == nil ? .opportunistic : .highQualityFormat,
                                            resize: .fast
                                        ) { image in
                                            if let image = image {
                                                self.updatePreview(image: image, for: .image(.duplicates))
                                            }
                                        }
                                    }
                                } else {
                                    commonModel.equality = commonModel.asset.creationDate?.timeIntervalSince1970 ?? 0
                                    if let prevDuplicateModel = previousDuplicateModel {
                                        if self.cacheService.getDuplicate(id: prevDuplicateModel.asset.localIdentifier) == nil {
                                            self.cacheService.setDuplicate(
                                                id: prevDuplicateModel.asset.localIdentifier,
                                                value: false,
                                                equality: prevDuplicateModel.asset.creationDate?.timeIntervalSince1970 ?? 0
                                            )
                                        }
                                    }
                                }
                                previousDuplicateModel = commonModel
                                previousDuplicateImage = image
                            }
                        }
                    }
                }

                // MARK: - Similar and screenshots
                if let previousModel = previousSimilarModel {
                    if
                        let location1 = previousModel.asset.location,
                        let location2 = asset.location,
                        let date1 = previousModel.asset.creationDate,
                        let date2 = asset.creationDate,
                        abs(date2.timeIntervalSince1970 - date1.timeIntervalSince1970) < 5,
                        location1.distance(from: location2) < 1
                    {
                        commonModel.similarity = previousModel.similarity
                        if self.insertSimilar(previousModel) {
                            self.addMegabytes(count: previousModel.asset.fakeSize, to: .image(.similar))
                        }
                        if self.insertSimilar(commonModel) {
                            self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.similar))
                        }
                        if self.similarImagePreview.value == nil || index > similarPreviewIndexThreshold || index == total - 1 {
                            similarPreviewIndexThreshold = index + total / 20
                            self.getPhotoPreview(asset, resize: .fast) { image in
                                if let image = image {
                                    self.updatePreview(image: image, for: .image(.similar))
                                }
                            }
                        }
                    } else {
                        commonModel.similarity = index
                    }
                }
                previousSimilarModel = commonModel

                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    if self.insertScreenshot(commonModel) {
                        self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.screenshots))
                    }
                    if self.screenshotImagePreview.value == nil || index > screenshotPreviewIndexThreshold || index == total - 1 {
                        screenshotPreviewIndexThreshold = index + total / 20
                        self.getPhotoPreview(asset, resize: .fast) { image in
                            if let image = image {
                                self.updatePreview(image: image, for: .image(.screenshots))
                            }
                        }
                    }
                }

                // MARK: - Detecting blurred
                if let isBlurred = self.cacheService.getBlurred(id: commonModel.asset.localIdentifier) {
                    if isBlurred {
                        if self.insertBlurred(commonModel) {
                            self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.blurred))
                        }
                        if self.blurredImagePreview.value == nil || index > blurredPreviewIndexThreshold || index == total - 1 {
                            blurredPreviewIndexThreshold = index + total / 20
                            self.getPhotoPreview(commonModel.asset, resize: .fast) { image in
                                if let image = image {
                                    self.updatePreview(image: image, for: .image(.blurred))
                                }
                            }
                        }
                    }
                } else {
                    self.getPhotoPreview(commonModel.asset) { image in
                        self.blurDetectionQueue.async {
                            if let image = image {
                                if self.imageProcessor.isBlurry(image) {
                                    if self.insertBlurred(commonModel) {
                                        self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.blurred))
                                    }
                                    self.updatePreview(image: image, for: .image(.blurred))
                                    self.cacheService.setBlurred(id: asset.localIdentifier, value: true)
                                } else {
                                    self.cacheService.setBlurred(id: asset.localIdentifier, value: false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func scanVideos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let videoFetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        self.videoFetchResult = videoFetchResult
        
        if videoFetchResult.count == 0 {
            return
        }

        let previewSide = (UIScreen.main.bounds.width - 40) / 2
        let previewSize = CGSize(width: previewSide, height: previewSide)
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .fast
        let previewIndicies: Set<Int> = {
            var out: Set<Int> = []
            let step = videoFetchResult.count / 3
            var index = 0
            while index < videoFetchResult.count {
                out.insert(index)
                index += step
            }
            out.insert(videoFetchResult.count - 1)
            return out
        }()

        videoScanningQueue.async {
            videoFetchResult.enumerateObjects { asset, index, _ in
                let model = AICleanServiceModel(imageManager: self.cachingImageManager, asset: asset, index: index)
                if self.insertVideo(model) {
                    self.addMegabytes(count: model.asset.fakeSize, to: .video)
                }
                if previewIndicies.contains(index) {
                    self.cachingImageManager.requestImage(
                        for: asset,
                        targetSize: previewSize,
                        contentMode: .aspectFill,
                        options: requestOptions
                    ) { image, _ in
                        if let image = image {
                            self.updatePreview(image: image, for: .video)
                        }
                    }
                }
            }
        }
    }

    func resetData() {
        progressSubject.send(AICleanServiceProgress(type: .image(.similar), index: 1, value: 0, isFinished: false))
        countsSubject.send(AICleanServiceCounts<Int>())
        megabytesSubject.send(AICleanServiceCounts<Double>())
        previewsSubject.send(AICleanServicePreviews(_similar: nil, _duplicates: nil, _blurred: nil, _screenshots: nil, _videos: nil))
        
        similarImages.removeAll()
        duplicateImages.removeAll()
        blurredImages.removeAll()
        screenshotImages.removeAll()
        videoAssets.removeAll()
    }
    
    func getMedia(_ type: AICleanServiceType) -> [AICleanServiceSection] {
        let sections: [AICleanServiceSection] = {
            switch type {
            case .image(let imageType):
                switch imageType {
                case .duplicates:
                    if duplicateImages.isEmpty { return [] }
                    return duplicateImages.equalitySections
                case .similar:
                    if similarImages.isEmpty { return [] }
                    return similarImages.similaritySections
                case .screenshots:
                    if screenshotImages.isEmpty { return [] }
                    return screenshotImages.dateSections
                case .blurred:
                    if blurredImages.isEmpty { return [] }
                    return blurredImages.dateSections
                }
            case .video:
                if videoAssets.isEmpty { return [] }
                return videoAssets.dateSections
            case .audio:
                if audioAssets.isEmpty { return [] }
                return audioAssets.dateSections
            }
        }()

        return sections
    }

    func delete(assets: Set<PHAsset>, completion: @escaping (Bool) -> Void) {
        photoLibrary.performChanges({
            PHAssetChangeRequest.deleteAssets(Array(assets) as NSArray)
        }, completionHandler: { result, error in
            completion(result)
        })
    }

    func deleteAssets(localIdentifiers: [String], completion: @escaping (Result<[String], Error>) -> Void) {
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        
        let assetsArray = assetsToDelete.objects(at: IndexSet(0..<assetsToDelete.count))
        
        let assetsToDeleteAsNSArray = assetsArray as NSArray
        
        photoLibrary.performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDeleteAsNSArray)
        }) { success, error in
            if success {
                completion(.success(localIdentifiers))
            } else {
                completion(.failure(error ?? NSError(domain: "DeleteAssetsError", code: -1, userInfo: nil)))
            }
        }
    }
    
    func updateCountsAndPreviews() {
        scanAllImages()
        scanVideos()
    }
    
    // MARK: - PHPhotoLibraryChangeObserver conformance
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        if let imageFetch = imageFetchResult, let info = changeInstance.changeDetails(for: imageFetch) {
            if !info.insertedObjects.isEmpty {
                cacheService.deleteAllDuplicates()
            }
            for object in info.removedObjects {
                if let first = similarImages.first(where: { $0.asset.isEqual(object) }) {
                    if similarImages.remove(first) != nil {
                        cacheService.deleteSize(id: first.asset.localIdentifier)
                        mediaWasDeletedSubject.send(.image(.similar))
                    }
                }
                if let first = duplicateImages.first(where: { $0.asset.isEqual(object) }) {
                    if duplicateImages.remove(first) != nil {
                        cacheService.deleteDuplicate(id: first.asset.localIdentifier)
                        let rest = duplicateImages.compactMap { $0.equality == first.equality ? $0 : nil }
                        if rest.count == 1 {
                            let another = rest.first!
                            duplicateImages.remove(another)
                            cacheService.deleteDuplicate(id: another.asset.localIdentifier)
                        }
                        mediaWasDeletedSubject.send(.image(.duplicates))
                    }
                }
                if let first = blurredImages.first(where: { $0.asset.isEqual(object) }) {
                    if blurredImages.remove(first) != nil {
                        cacheService.deleteBlurred(id: first.asset.localIdentifier)
                        mediaWasDeletedSubject.send(.image(.blurred))
                    }
                }
                if let first = screenshotImages.first(where: { $0.asset.isEqual(object) }) {
                    if screenshotImages.remove(first) != nil {
                        cacheService.deleteSize(id: first.asset.localIdentifier)
                        mediaWasDeletedSubject.send(.image(.screenshots))
                    }
                }
            }
        }
        if let videoFetch = videoFetchResult, let info = changeInstance.changeDetails(for: videoFetch) {
            for object in info.removedObjects {
                if let first = videoAssets.first(where: { $0.asset.isEqual(object) }) {
                    if videoAssets.remove(first) != nil {
                        cacheService.deleteSize(id: first.asset.localIdentifier)
                        mediaWasDeletedSubject.send(.video)
                    }
                }
            }
        }
    }
}

private extension AIMainCleanService {
    func insertSimilar(_ model: AICleanServiceModel) -> Bool {
        similarImages.insert(model).inserted
    }
    
    func insertDuplicate(_ model: AICleanServiceModel) -> Bool {
        duplicateImages.insert(model).inserted
    }
    
    func insertBlurred(_ model: AICleanServiceModel) -> Bool {
        blurredImages.insert(model).inserted
    }
    
    func insertScreenshot(_ model: AICleanServiceModel) -> Bool {
        screenshotImages.insert(model).inserted
    }
    
    func insertVideo(_ model: AICleanServiceModel) -> Bool {
        videoAssets.insert(model).inserted
    }

    func addMegabytes(count: Double, to type: AICleanServiceType) {
        let currentMegabytes = megabytesSubject.value
        currentMegabytes.add(count: count, to: type)
        megabytesSubject.send(currentMegabytes)
    }
    
    func updatePreview(image: UIImage, for type: AICleanServiceType) {
        let currentPreviews = previewsSubject.value
        let newPreviews: AICleanServicePreviews
        
        switch type {
        case .image(let imageType):
            switch imageType {
            case .similar:
                similarImagePreview.send(image)
                newPreviews = AICleanServicePreviews(
                    _similar: image,
                    _duplicates: currentPreviews.duplicates,
                    _blurred: currentPreviews.blurred,
                    _screenshots: currentPreviews.screenshots,
                    _videos: currentPreviews.videos
                )
            case .duplicates:
                duplicateImagePreview.send(image)
                newPreviews = AICleanServicePreviews(
                    _similar: currentPreviews.similar,
                    _duplicates: image,
                    _blurred: currentPreviews.blurred,
                    _screenshots: currentPreviews.screenshots,
                    _videos: currentPreviews.videos
                )
            case .blurred:
                blurredImagePreview.send(image)
                newPreviews = AICleanServicePreviews(
                    _similar: currentPreviews.similar,
                    _duplicates: currentPreviews.duplicates,
                    _blurred: image,
                    _screenshots: currentPreviews.screenshots,
                    _videos: currentPreviews.videos
                )
            case .screenshots:
                screenshotImagePreview.send(image)
                newPreviews = AICleanServicePreviews(
                    _similar: currentPreviews.similar,
                    _duplicates: currentPreviews.duplicates,
                    _blurred: currentPreviews.blurred,
                    _screenshots: image,
                    _videos: currentPreviews.videos
                )
            }
        case .video:
            videoPreview.send(image)
            newPreviews = AICleanServicePreviews(
                _similar: currentPreviews.similar,
                _duplicates: currentPreviews.duplicates,
                _blurred: currentPreviews.blurred,
                _screenshots: currentPreviews.screenshots,
                _videos: image
            )
        case .audio:
            return
        }
        previewsSubject.send(newPreviews)
    }
    
    func getPhotoPreview(
        _ asset: PHAsset,
        delivery: PHImageRequestOptionsDeliveryMode = .highQualityFormat,
        resize: PHImageRequestOptionsResizeMode = .exact,
        completion: @escaping (UIImage?) -> Void
    ) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = delivery
        requestOptions.resizeMode = resize
        cachingImageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 450, height: 450),
            contentMode: .aspectFit,
            options: requestOptions
        ) { image, _ in
            completion(image)
        }
    }
}
