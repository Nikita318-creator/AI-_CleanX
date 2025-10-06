import Foundation
import Photos
import UIKit
import Vision
import CryptoKit
import CoreImage

@MainActor
final class PicsAnalyserService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var duplicateGroups: [PhotoGroupModel] = []
    @Published var similarGroups: [PhotoGroupModel] = []
    
    private let assetManager = PHImageManager.default()
    private var currentTask: Task<Void, Never>?
    
    func findDuplicatePhotos() async {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        analysisProgress = 0.0
        duplicateGroups = []
        
        do {
            let assets = try await retrieveAllPhotos()
            let duplicates = await processDuplicates(assets: assets)
            self.duplicateGroups = duplicates
        } catch {
        }
        
        isAnalyzing = false
        analysisProgress = 1.0
    }
    
    func findSimilarPhotos() async {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        analysisProgress = 0.0
        similarGroups = []
        
        do {
            let assets = try await retrieveAllPhotos()
            let similar = await processSimilarPhotos(assets: assets)
            self.similarGroups = similar
        } catch {
        }
        
        isAnalyzing = false
        analysisProgress = 1.0
    }
    
    func cancelAnalysis() {
        currentTask?.cancel()
        currentTask = nil
        isAnalyzing = false
        analysisProgress = 0.0
    }
    
    private func retrieveAllPhotos() async throws -> [PHAsset] {
        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            
            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            var assets: [PHAsset] = []
            
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            continuation.resume(returning: assets)
        }
    }
    
    private func processDuplicates(assets: [PHAsset]) async -> [PhotoGroupModel] {
        var imageData: [(PhotoAssetModel, [Float], String)] = []
        let totalAssets = min(assets.count, 300)
        
        for (index, asset) in assets.prefix(totalAssets).enumerated() {
            await MainActor.run {
                self.analysisProgress = Double(index) / Double(totalAssets)
            }
            
            if let image = await loadAssetImage(from: asset) {
                let photoModel = PhotoAssetModel(asset: asset, image: image)
                let hash = generateImageHash(image: image) ?? ""
                
                if let features = await extractVisionFeatures(from: image) {
                    imageData.append((photoModel, features, hash))
                }
            }
        }
        
        return createDuplicateGroups(imageData: imageData)
    }
    
    private func processSimilarPhotos(assets: [PHAsset]) async -> [PhotoGroupModel] {
        var imageData: [(PhotoAssetModel, String, [Float]?)] = []
        let totalAssets = min(assets.count, 150)
        
        let batchSize = 10
        let assetBatches = Array(assets.prefix(totalAssets)).chunked(into: batchSize)
        
        for (batchIndex, batch) in assetBatches.enumerated() {
            await withTaskGroup(of: (PhotoAssetModel, String, [Float]?)?.self) { group in
                for asset in batch {
                    group.addTask {
                        if let image = await self.loadAssetImage(from: asset) {
                            let photoModel = PhotoAssetModel(asset: asset, image: image)
                            let hash = await self.generateImageHashAsync(image: image) ?? ""
                            let features = await self.extractVisionFeatures(from: image)
                            return (photoModel, hash, features)
                        }
                        return nil
                    }
                }
                
                for await result in group {
                    if let result = result {
                        imageData.append(result)
                    }
                }
            }
            
            await MainActor.run {
                self.analysisProgress = Double((batchIndex + 1) * batchSize) / Double(totalAssets)
            }
        }
        
        return createSimilarGroups(imageData: imageData)
    }
    
    private func loadAssetImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            let targetSize = CGSize(width: 256, height: 256)
            
            assetManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func generateImageHashAsync(image: UIImage) async -> String? {
        return generateImageHash(image: image)
    }
    
    private func generateImageHash(image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let resizedCGImage = resizedImage.cgImage else { return nil }
        
        let width = resizedCGImage.width
        let height = resizedCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context2 = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        
        context2?.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var totalBrightness: Int = 0
        var grayscaleValues: [Int] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                let r = Int(pixelData[pixelIndex])
                let g = Int(pixelData[pixelIndex + 1])
                let b = Int(pixelData[pixelIndex + 2])
                
                let gray = Int(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
                grayscaleValues.append(gray)
                totalBrightness += gray
            }
        }
        
        let averageBrightness = totalBrightness / (width * height)
        
        var hash = ""
        for brightness in grayscaleValues {
            hash += brightness > averageBrightness ? "1" : "0"
        }
        
        return hash
    }
    
    private func calculateHammingDistance(_ hash1: String, _ hash2: String) -> Int {
        guard hash1.count == hash2.count else { return Int.max }
        
        var distance = 0
        for (char1, char2) in zip(hash1, hash2) {
            if char1 != char2 {
                distance += 1
            }
        }
        return distance
    }
    
    private func extractVisionFeatures(from image: UIImage) async -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let observations = request.results as? [VNFeaturePrintObservation],
                      let featurePrint = observations.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let features = featurePrint.data.withUnsafeBytes { bytes in
                    Array(bytes.bindMemory(to: Float.self))
                }
                
                continuation.resume(returning: features)
            }
            
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: .up,
                options: [
                    VNImageOption.ciContext: CIContext(options: [.useSoftwareRenderer: false])
                ]
            )
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func createDuplicateGroups(imageData: [(PhotoAssetModel, [Float], String)]) -> [PhotoGroupModel] {
        var groups: [PhotoGroupModel] = []
        var processed: Set<String> = []
        
        for (i, (photo1, features1, hash1)) in imageData.enumerated() {
            if processed.contains(photo1.localIdentifier) { continue }
            
            var duplicatePhotos: [PhotoAssetModel] = [photo1]
            processed.insert(photo1.localIdentifier)
            
            for (j, (photo2, features2, hash2)) in imageData.enumerated() {
                if i == j || processed.contains(photo2.localIdentifier) { continue }
                
                var isDuplicate = false
                
                let hashDistance = calculateHammingDistance(hash1, hash2)
                if hashDistance <= 3 {
                    isDuplicate = true
                }
                
                if !isDuplicate {
                    let similarity = calculateCosineSimilarity(features1, features2)
                    if similarity > 0.95 {
                        isDuplicate = true
                    }
                }
                
                if isDuplicate {
                    duplicatePhotos.append(photo2)
                    processed.insert(photo2.localIdentifier)
                }
            }
            
            if duplicatePhotos.count > 1 {
                if let bestIndex = findBestPhotoInGroup(in: duplicatePhotos) {
                    duplicatePhotos[bestIndex].isBest = true
                }
                
                let group = PhotoGroupModel(groupType: .duplicates, photos: duplicatePhotos)
                groups.append(group)
            }
        }
        
        return groups.sorted { $0.photos.count > $1.photos.count }
    }
    
    private func createSimilarGroups(imageData: [(PhotoAssetModel, String, [Float]?)]) -> [PhotoGroupModel] {
        var groups: [PhotoGroupModel] = []
        var processed: Set<String> = []
        
        for (i, (photo1, hash1, features1)) in imageData.enumerated() {
            if processed.contains(photo1.localIdentifier) { continue }
            
            var similarPhotos: [PhotoAssetModel] = [photo1]
            processed.insert(photo1.localIdentifier)
            
            for (j, (photo2, hash2, features2)) in imageData.enumerated() {
                if i == j || processed.contains(photo2.localIdentifier) { continue }
                
                var isSimilar = false
                var similarity: Double = 0.0
                
                let hashDistance = calculateHammingDistance(hash1, hash2)
                if hashDistance <= 15 {
                    similarity = 1.0 - (Double(hashDistance) / 64.0)
                    isSimilar = true
                }
                
                if !isSimilar, let f1 = features1, let f2 = features2 {
                    let cosineSim = calculateCosineSimilarity(f1, f2)
                    if cosineSim > 0.75 {
                        similarity = cosineSim
                        isSimilar = true
                    }
                }
                
                if isSimilar {
                    var similarPhoto = photo2
                    similarPhoto.similarityScore = similarity
                    similarPhotos.append(similarPhoto)
                    processed.insert(photo2.localIdentifier)
                }
            }
            
            if similarPhotos.count > 1 {
                if let bestIndex = findBestPhotoInGroup(in: similarPhotos) {
                    similarPhotos[bestIndex].isBest = true
                }
                
                let group = PhotoGroupModel(groupType: .similar, photos: similarPhotos)
                groups.append(group)
            }
        }
        
        return groups.sorted { $0.photos.count > $1.photos.count }
    }
    
    private func calculateCosineSimilarity(_ vector1: [Float], _ vector2: [Float]) -> Double {
        guard vector1.count == vector2.count else { return 0.0 }
        
        let dotProduct = zip(vector1, vector2).map(*).reduce(0, +)
        let magnitude1 = sqrt(vector1.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(vector2.map { $0 * $0 }.reduce(0, +))
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }
        
        return Double(dotProduct / (magnitude1 * magnitude2))
    }
    
    private func findBestPhotoInGroup(in photos: [PhotoAssetModel]) -> Int? {
        guard !photos.isEmpty else { return nil }
        
        var bestIndex = 0
        var bestScore = 0.0
        
        for (index, photo) in photos.enumerated() {
            var score = 0.0
            
            let pixelCount = Double(photo.asset.pixelWidth * photo.asset.pixelHeight)
            score += pixelCount / 1_000_000.0
            
            if let creationDate = photo.creationDate {
                let daysSinceCreation = Date().timeIntervalSince(creationDate) / (24 * 60 * 60)
                score += max(0, 365 - daysSinceCreation) / 365.0
            }
            
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }
        
        return bestIndex
    }
}
