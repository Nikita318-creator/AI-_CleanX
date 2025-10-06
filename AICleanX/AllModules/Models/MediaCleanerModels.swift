import Foundation
import Photos
import UIKit
import Vision

// MARK: - Scanning State
enum ScanningState {
    case idle
    case scanning(progress: Double)
    case completed
}

// MARK: - Media Cleaner Category Types
enum MediaCleanerCategory: String, CaseIterable, Identifiable {
    case similar = "Similar"
    case videos = "Videos"
    case contacts = "Contacts"
    case calendar = "Calendar"
    case blurred = "Blurred"
    case duplicates = "Duplicates"
    case screenshots = "Screenshots"
    
    var id: String { rawValue }
}

// MARK: - Scan Result
struct ScanResult {
    let totalFiles: Int
    let totalSize: String
}

// MARK: - Photo Models for Similar/Duplicate Detection
struct PhotoAssetModel: Identifiable, Hashable {
    let id = UUID()
    let asset: PHAsset
    let image: UIImage?
    let localIdentifier: String
    let creationDate: Date?
    let fileSize: Int64
    let filename: String
    var isBest: Bool = false
    var similarityScore: Double = 0.0
    
    init(asset: PHAsset, image: UIImage? = nil) {
        self.asset = asset
        self.image = image
        self.localIdentifier = asset.localIdentifier
        self.creationDate = asset.creationDate
        self.fileSize = Int64(asset.pixelWidth * asset.pixelHeight * 4) // Приблизительный размер
        self.filename = asset.value(forKey: "filename") as? String ?? "Unknown"
    }
    
    static func == (lhs: PhotoAssetModel, rhs: PhotoAssetModel) -> Bool {
        return lhs.localIdentifier == rhs.localIdentifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(localIdentifier)
    }
}

// MARK: - Photo Group for Similar/Duplicate Photos
struct PhotoGroupModel: Identifiable {
    let id = UUID()
    let groupType: PhotoGroupType
    var photos: [PhotoAssetModel]
    let totalSize: Int64
    
    var title: String {
        switch groupType {
        case .duplicates:
            return "\(photos.count) duplicates"
        case .similar:
            return "\(photos.count) similar photos"
        }
    }
    
    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    init(groupType: PhotoGroupType, photos: [PhotoAssetModel]) {
        self.groupType = groupType
        self.photos = photos
        self.totalSize = photos.reduce(0) { $0 + $1.fileSize }
    }
}

// MARK: - Photo Group Type
enum PhotoGroupType {
    case duplicates
    case similar
}

// MARK: - Image Analysis Result
struct ImageAnalysisResult {
    let asset: PHAsset
    let fingerprint: String // Хеш для дубликатов
    let features: [Float]? // Векторы признаков для похожих изображений
    let error: Error?
}

// MARK: - Similar Photos Detection Mode
enum SimilarPhotosMode {
    case duplicates
    case similar
    
    var title: String {
        switch self {
        case .duplicates:
            return "Duplicates"
        case .similar:
            return "Similar"
        }
    }
}
