import Foundation
import UIKit
import AVFoundation
import os.log
   
class FileSystemStorageManager {
    private static let baseDirectoryName = "SafeStorage"
    private static let photosDirectoryName = "Photos"
    private static let videosDirectoryName = "Videos"
    private static let documentsDirectoryName = "Documents"
    private static let thumbnailsDirectoryName = "Thumbnails"
    
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private static var baseDirectory: URL {
        documentsDirectory.appendingPathComponent(baseDirectoryName)
    }
    
    static var photosDirectory: URL {
        baseDirectory.appendingPathComponent(photosDirectoryName)
    }
    
    static var videosDirectory: URL {
        baseDirectory.appendingPathComponent(videosDirectoryName)
    }
    
    static var documentsStorageDirectory: URL {
        baseDirectory.appendingPathComponent(documentsDirectoryName)
    }
    
    static var thumbnailsDirectory: URL {
        baseDirectory.appendingPathComponent(thumbnailsDirectoryName)
    }
    
    static func createDirectoriesIfNeeded() throws {
        let directories = [
            ("Base", baseDirectory),
            ("Photos", photosDirectory),
            ("Videos", videosDirectory),
            ("Documents", documentsStorageDirectory),
            ("Thumbnails", thumbnailsDirectory)
        ]
        
        for (_, directory) in directories {
            let directoryExists = FileManager.default.fileExists(atPath: directory.path)
            
            if !directoryExists {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    static func savePhoto(_ imageData: Data, fileName: String? = nil) throws -> (imageURL: URL, thumbnailURL: URL?) {
        let actualFileName = fileName ?? "photo_\(UUID().uuidString).jpg"
        
        do {
            try createDirectoriesIfNeeded()
            
            let imageURL = photosDirectory.appendingPathComponent(actualFileName)
            try imageData.write(to: imageURL)
            var thumbnailURL: URL?
            
            if let thumbnailData = generateThumbnail(from: imageData) {
                let thumbnailFileName = "thumb_\(actualFileName)"
                thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
                
                try thumbnailData.write(to: thumbnailURL!)
            }
                        
            return (imageURL: imageURL, thumbnailURL: thumbnailURL)
            
        } catch {
            throw error
        }
    }
    
    static func savePhotoAsync(_ imageData: Data, fileName: String? = nil) async throws -> (imageURL: URL, thumbnailURL: URL?) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try savePhoto(imageData, fileName: fileName)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    static func saveVideo(_ videoData: Data, fileName: String? = nil) throws -> (videoURL: URL, thumbnailURL: URL?) {
        let actualFileName = fileName ?? "video_\(UUID().uuidString).mp4"

        do {
            try createDirectoriesIfNeeded()
            
            let videoURL = videosDirectory.appendingPathComponent(actualFileName)
            try videoData.write(to: videoURL)
            var thumbnailURL: URL?
            
            do {
                thumbnailURL = try generateVideoThumbnail(from: videoURL)
            } catch {
                print("⚠️ Failed to generate video thumbnail: \(error.localizedDescription)")
            }
            
            return (videoURL: videoURL, thumbnailURL: thumbnailURL)
            
        } catch {
            throw error
        }
    }
    
    static func extractVideoDuration(from videoURL: URL) -> Double {
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration
        let durationSeconds = duration.seconds.isFinite ? duration.seconds : 0.0
        return durationSeconds
    }
    
    static func saveDocument(_ documentData: Data, fileName: String) throws -> URL {
        try createDirectoriesIfNeeded()
        let documentURL = documentsStorageDirectory.appendingPathComponent(fileName)
        try documentData.write(to: documentURL)
        return documentURL
    }
    
    // MARK: - Data Retrieval
    static func loadImage(from url: URL) -> UIImage? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        guard let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    static func loadImageData(from url: URL) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return data
    }
    
    static func loadThumbnail(from url: URL?) -> UIImage? {
        guard let url = url else {
            return nil
        }
                
        return loadImage(from: url)
    }
    
    static func deleteFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
                
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw error
        }
    }
    
    static func deletePhotoFiles(imageURL: URL, thumbnailURL: URL?) throws {
        do {
            try deleteFile(at: imageURL)
            if let thumbnailURL = thumbnailURL {
                try deleteFile(at: thumbnailURL)
            }
        } catch {
            throw error
        }
    }
    
    static func deleteVideoFiles(videoURL: URL, thumbnailURL: URL?) throws {
        do {
            try deleteFile(at: videoURL)
            
            if let thumbnailURL = thumbnailURL {
                try deleteFile(at: thumbnailURL)
            }
        } catch {
            throw error
        }
    }
    
    static func fileSize(at url: URL) -> Int64 {
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return 0 }
        return attributes[.size] as? Int64 ?? 0
    }
    
    private static func generateThumbnail(from imageData: Data, maxSize: CGFloat = 150) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        let size = image.size
        let aspectRatio = size.width / size.height
        let thumbnailSize: CGSize
        
        if aspectRatio > 1 {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        guard let cgImage = image.cgImage else { return nil }
        context.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))
        
        guard let thumbnailCGImage = context.makeImage() else { return nil }
        let thumbnail = UIImage(cgImage: thumbnailCGImage)
        
        return thumbnail.jpegData(compressionQuality: 0.7)
    }
    
    static func generateVideoThumbnail(from videoURL: URL) throws -> URL {
        try createDirectoriesIfNeeded()
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: min(1.0, asset.duration.seconds), preferredTimescale: 600)
        
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        let image = UIImage(cgImage: cgImage)
        
        let thumbnailImage = try resizeImageForThumbnail(image, maxSize: 150)
        
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7) else {
            throw SystemFileErrors.thumbnailGenerationFailed
        }
        
        let thumbnailFileName = "thumb_\(videoURL.lastPathComponent).jpg"
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
        try thumbnailData.write(to: thumbnailURL)
        
        return thumbnailURL
    }
    
    private static func resizeImageForThumbnail(_ image: UIImage, maxSize: CGFloat) throws -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        let thumbnailSize: CGSize
        
        if aspectRatio > 1 {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw SystemFileErrors.thumbnailGenerationFailed
        }
        guard let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw SystemFileErrors.thumbnailGenerationFailed
        }
        
        guard let cgImage = image.cgImage else {
            throw SystemFileErrors.thumbnailGenerationFailed
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))
        
        guard let thumbnailCGImage = context.makeImage() else {
            throw SystemFileErrors.thumbnailGenerationFailed
        }
        
        return UIImage(cgImage: thumbnailCGImage)
    }
    
    static func getStorageStatistics() -> (totalFiles: Int, totalSizeBytes: Int64) {
        let directories = [photosDirectory, videosDirectory, documentsStorageDirectory, thumbnailsDirectory]
        var totalFiles = 0
        var totalSize: Int64 = 0
        
        for directory in directories {
            guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalFiles += 1
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return (totalFiles: totalFiles, totalSizeBytes: totalSize)
    }
    
    static func cleanupOrphanedFiles() throws {}
}
