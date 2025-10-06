import Foundation
import UIKit
import CoreData
import os.log

// MARK: - Core Data Persistence Controller
struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Add sample data for previews
        // Note: Contact preview data is now managed by ContactsPersistenceManager
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SafeStorage")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// MARK: - Safe Photo Data Model
struct SafePhotoData: Identifiable {
    let id: UUID
    let imageURL: URL
    let thumbnailURL: URL?
    let fileName: String
    let fileSize: Int64
    let dateAdded: Date
    let createdAt: Date
    let modifiedAt: Date
    
    init(imageURL: URL, thumbnailURL: URL?, fileName: String, fileSize: Int64) {
        self.id = UUID()
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.dateAdded = Date()
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // Add a different initializer for loading from metadata
    init(id: UUID, imageURL: URL, thumbnailURL: URL?, fileName: String, fileSize: Int64, dateAdded: Date, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    var thumbnailImage: UIImage? {
        guard let url = thumbnailURL else { return nil }
        return FileSystemStorageManager.loadThumbnail(from: url)
    }
    
    var fullImage: UIImage? {
        let image = FileSystemStorageManager.loadImage(from: imageURL)
        if image == nil {
            print("Warning: Could not load image from \(imageURL.path)")
            print("File exists: \(FileManager.default.fileExists(atPath: imageURL.path))")
        }
        return image
    }
}

// MARK: - Safe Document Data Model
struct SafeDocumentData: Identifiable {
    let id: UUID
    let documentURL: URL
    let fileName: String
    let fileSize: Int64
    let fileExtension: String?
    let mimeType: String?
    let dateAdded: Date
    let createdAt: Date
    let modifiedAt: Date
    
    init(documentURL: URL, fileName: String, fileSize: Int64, fileExtension: String? = nil, mimeType: String? = nil) {
        self.id = UUID()
        self.documentURL = documentURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileExtension = fileExtension
        self.mimeType = mimeType
        self.dateAdded = Date()
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // Initializer for loading from metadata
    init(id: UUID, documentURL: URL, fileName: String, fileSize: Int64, fileExtension: String?, mimeType: String?, dateAdded: Date, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.documentURL = documentURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileExtension = fileExtension
        self.mimeType = mimeType
        self.dateAdded = dateAdded
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var displayName: String {
        let maxLength = 25
        if fileName.count <= maxLength {
            return fileName
        }
        
        let startIndex = fileName.startIndex
        let endIndex = fileName.index(startIndex, offsetBy: maxLength - 3)
        return String(fileName[startIndex..<endIndex]) + "..."
    }
    
    var iconName: String {
        guard let ext = fileExtension?.lowercased() else { return "doc.fill" }
        
        switch ext {
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.text.fill"
        case "xls", "xlsx":
            return "tablecells.fill"
        case "ppt", "pptx":
            return "rectangle.fill.on.rectangle.fill"
        case "txt":
            return "doc.plaintext.fill"
        case "rtf":
            return "doc.richtext.fill"
        case "zip", "rar", "7z":
            return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        case "mp3", "wav", "aac":
            return "music.note"
        default:
            return "doc.fill"
        }
    }
}

// MARK: - Safe Video Data Model
struct SafeVideoData: Identifiable {
    let id: UUID
    let videoURL: URL
    let thumbnailURL: URL?
    let fileName: String
    let fileSize: Int64
    let duration: Double
    let dateAdded: Date
    let createdAt: Date
    let modifiedAt: Date
    
    init(videoURL: URL, thumbnailURL: URL?, fileName: String, fileSize: Int64, duration: Double) {
        self.id = UUID()
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.duration = duration
        self.dateAdded = Date()
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // Initializer for loading from metadata
    init(id: UUID, videoURL: URL, thumbnailURL: URL?, fileName: String, fileSize: Int64, duration: Double, dateAdded: Date, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.duration = duration
        self.dateAdded = dateAdded
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    var thumbnailImage: UIImage? {
        guard let url = thumbnailURL else { return nil }
        return FileSystemStorageManager.loadThumbnail(from: url)
    }
    
    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - Safe Storage Metadata
struct SafePhotoMetadata: Codable {
    let id: String
    let imageFileName: String?  // Store relative filename only (optional for migration)
    let thumbnailFileName: String?  // Store relative filename only
    let fileName: String
    let fileSize: Int64
    let dateAdded: Date
    let createdAt: Date
    let modifiedAt: Date
    
    // Legacy support for old absolute paths
    let imageURL: String?
    let thumbnailURL: String?
    
    init(id: String, imageFileName: String, thumbnailFileName: String?, fileName: String, fileSize: Int64, dateAdded: Date, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.fileName = fileName
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.imageURL = nil  // Not used in new format
        self.thumbnailURL = nil  // Not used in new format
    }
}

struct SafeDocumentMetadata: Codable {
    let id: String
    let documentFileName: String?  // Store relative filename only (optional for migration)
    let fileName: String
    let fileSize: Int64
    let fileExtension: String?
    let mimeType: String?
    let dateAdded: Date
    let createdAt: Date
    let modifiedAt: Date
    
    // Legacy support for old absolute paths
    let documentURL: String?
    
    init(id: String, documentFileName: String, fileName: String, fileSize: Int64, fileExtension: String?, mimeType: String?, dateAdded: Date, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.documentFileName = documentFileName
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileExtension = fileExtension
        self.mimeType = mimeType
        self.dateAdded = dateAdded
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.documentURL = nil  // Not used in new format
    }
}

struct SafeVideoMetadata: Codable {
    let id: String
    let videoFileName: String?  // Store relative filename only (optional for migration)
    let thumbnailFileName: String?  // Store relative filename only
    let fileName: String
    let fileSize: Int64
    let duration: Double
    let dateAdded: Date
    let createdAt: Date
    let modifiedAt: Date
    
    // Legacy support for old absolute paths
    let videoURL: String?
    let thumbnailURL: String?
    
    init(id: String, videoFileName: String, thumbnailFileName: String?, fileName: String, fileSize: Int64, duration: Double, dateAdded: Date, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.videoFileName = videoFileName
        self.thumbnailFileName = thumbnailFileName
        self.fileName = fileName
        self.fileSize = fileSize
        self.duration = duration
        self.dateAdded = dateAdded
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.videoURL = nil  // Not used in new format
        self.thumbnailURL = nil  // Not used in new format
    }
}

// MARK: - Safe Storage Manager
class SafeStorageManager: ObservableObject {
    @Published var photos: [SafePhotoData] = []
    @Published var videos: [SafeVideoData] = []
    @Published var documents: [SafeDocumentData] = []
    
    // MARK: - Logging
    private let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "SafeStorageManager")
    
    private let photosMetadataFileName = "photos_metadata.json"
    private let videosMetadataFileName = "videos_metadata.json"
    private let documentsMetadataFileName = "documents_metadata.json"
    
    private var photosMetadataURL: URL {
        FileSystemStorageManager.documentsDirectory.appendingPathComponent(photosMetadataFileName)
    }
    
    private var videosMetadataURL: URL {
        FileSystemStorageManager.documentsDirectory.appendingPathComponent(videosMetadataFileName)
    }
    
    private var documentsMetadataURL: URL {
        FileSystemStorageManager.documentsDirectory.appendingPathComponent(documentsMetadataFileName)
    }
    
    init() {
        logger.info("🏁 Initializing SafeStorageManager")
        
        // Ensure storage directories are created
        do {
            try FileSystemStorageManager.createDirectoriesIfNeeded()
            logger.info("✅ Storage directories initialized successfully")
        } catch {
            logger.error("❌ Error creating storage directories: \(error.localizedDescription)")
        }
        
        loadPhotos()
        loadVideos()
        loadDocuments()
        
        logger.info("✅ SafeStorageManager initialization completed - Photos: \(self.photos.count), Videos: \(self.videos.count), Documents: \(self.documents.count)")
    }
    
    // MARK: - Photo Management
    func savePhoto(imageData: Data, fileName: String? = nil) -> SafePhotoData? {
        let actualFileName = fileName ?? "photo_\(UUID().uuidString).jpg"
        logger.info("💾 Saving photo to SafeStorageManager - FileName: \(actualFileName)")
        
        do {
            // Save image to file system
            let (imageURL, thumbnailURL) = try FileSystemStorageManager.savePhoto(imageData, fileName: actualFileName)
            
            // Create local model
            let photo = SafePhotoData(
                imageURL: imageURL,
                thumbnailURL: thumbnailURL,
                fileName: actualFileName,
                fileSize: Int64(imageData.count)
            )
            
            photos.append(photo)
            logger.debug("📷 Added photo to local collection - Total photos: \(self.photos.count)")
            
            // Save metadata
            savePhotosMetadata()
            
            logger.info("✅ Photo saved successfully to SafeStorageManager")
            return photo
            
        } catch {
            logger.error("❌ Error saving photo to SafeStorageManager: \(error.localizedDescription)")
            return nil
        }
    }
    
    func savePhotoAsync(imageData: Data, fileName: String? = nil) async -> SafePhotoData? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = self?.savePhoto(imageData: imageData, fileName: fileName)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    func loadAllPhotos() -> [SafePhotoData] {
        return photos.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    func deletePhoto(_ photo: SafePhotoData) {
        do {
            // Delete from file system
            try FileSystemStorageManager.deletePhotoFiles(
                imageURL: photo.imageURL,
                thumbnailURL: photo.thumbnailURL
            )
            
            // Remove from local array
            photos.removeAll { $0.id == photo.id }
            
            // Save updated metadata
            savePhotosMetadata()
            
        } catch {
            print("Error deleting photo: \(error)")
        }
    }
    
    func deletePhotos(_ photosToDelete: [SafePhotoData]) {
        for photo in photosToDelete {
            deletePhoto(photo)
        }
    }
    
    // MARK: - Metadata Management
    private func savePhotosMetadata() {
        logger.debug("💾 Saving photos metadata - Count: \(self.photos.count)")
        
        do {
            let metadata = photos.map { photo in
                SafePhotoMetadata(
                    id: photo.id.uuidString,
                    imageFileName: photo.imageURL.lastPathComponent,  // Store only filename
                    thumbnailFileName: photo.thumbnailURL?.lastPathComponent,  // Store only filename
                    fileName: photo.fileName,
                    fileSize: photo.fileSize,
                    dateAdded: photo.dateAdded,
                    createdAt: photo.createdAt,
                    modifiedAt: photo.modifiedAt
                )
            }
            
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: photosMetadataURL)
            
            logger.debug("✅ Photos metadata saved successfully - Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
        } catch {
            logger.error("❌ Error saving photos metadata: \(error.localizedDescription)")
        }
    }
    
    private func saveVideosMetadata() {
        logger.debug("💾 Saving videos metadata - Count: \(self.videos.count)")
        
        do {
            let metadata = videos.map { video in
                SafeVideoMetadata(
                    id: video.id.uuidString,
                    videoFileName: video.videoURL.lastPathComponent,  // Store only filename
                    thumbnailFileName: video.thumbnailURL?.lastPathComponent,  // Store only filename
                    fileName: video.fileName,
                    fileSize: video.fileSize,
                    duration: video.duration,
                    dateAdded: video.dateAdded,
                    createdAt: video.createdAt,
                    modifiedAt: video.modifiedAt
                )
            }
            
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: videosMetadataURL)
            
            logger.debug("✅ Videos metadata saved successfully - Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
        } catch {
            logger.error("❌ Error saving videos metadata: \(error.localizedDescription)")
        }
    }
    
    private func loadPhotos() {
        logger.info("📖 Loading photos from metadata")
        
        do {
            guard FileManager.default.fileExists(atPath: photosMetadataURL.path) else {
                logger.debug("ℹ️ No photos metadata file found, starting with empty collection")
                photos = []
                return
            }
            
            let data = try Data(contentsOf: photosMetadataURL)
            logger.debug("📖 Photos metadata file size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
            let metadata = try JSONDecoder().decode([SafePhotoMetadata].self, from: data)
            
            photos = metadata.compactMap { meta in
                // Migration logic: handle both new format (relative paths) and old format (absolute paths)
                let imageURL: URL
                let thumbnailURL: URL?
                
                if let imageFileName = meta.imageFileName {
                    // New format: use relative filenames and construct full paths
                    imageURL = FileSystemStorageManager.photosDirectory.appendingPathComponent(imageFileName)
                    thumbnailURL = meta.thumbnailFileName.map { 
                        FileSystemStorageManager.thumbnailsDirectory.appendingPathComponent($0) 
                    }
                    logger.debug("📱 Using new relative path format for photo: \(imageFileName)")
                } else if let oldImagePath = meta.imageURL {
                    // Legacy format: extract filename from old absolute path
                    let imageFileName = URL(fileURLWithPath: oldImagePath).lastPathComponent
                    imageURL = FileSystemStorageManager.photosDirectory.appendingPathComponent(imageFileName)
                    
                    if let oldThumbnailPath = meta.thumbnailURL {
                        let thumbnailFileName = URL(fileURLWithPath: oldThumbnailPath).lastPathComponent
                        thumbnailURL = FileSystemStorageManager.thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
                    } else {
                        thumbnailURL = nil
                    }
                    logger.debug("🔄 Migrated from absolute path for photo: \(imageFileName)")
                } else {
                    logger.error("❌ Invalid metadata entry - no valid path found for photo ID: \(meta.id)")
                    return nil
                }
                
                return SafePhotoData(
                    id: UUID(uuidString: meta.id) ?? UUID(),
                    imageURL: imageURL,
                    thumbnailURL: thumbnailURL,
                    fileName: meta.fileName,
                    fileSize: meta.fileSize,
                    dateAdded: meta.dateAdded,
                    createdAt: meta.createdAt,
                    modifiedAt: meta.modifiedAt
                )
            }
            
            logger.info("✅ Successfully loaded \(self.photos.count) photos from metadata")
            
            // Check if we loaded any legacy data and need to migrate
            let hasLegacyData = metadata.contains { $0.imageFileName == nil && $0.imageURL != nil }
            if hasLegacyData {
                logger.info("🔄 Detected legacy absolute paths, migrating to new relative path format...")
                savePhotosMetadata()  // Save in new format
                logger.info("✅ Migration completed successfully")
            }
            
        } catch {
            logger.error("❌ Error loading photos: \(error.localizedDescription)")
            photos = []
        }
    }
    
    // MARK: - Count Methods for UI
    func getPhotosCount() -> Int {
        return photos.count
    }
    
    func getDocumentsCount() -> Int {
        return documents.count
    }
    
    func getVideosCount() -> Int {
        return videos.count
    }
    
    func getContactsCount() -> Int {
        // Use the new ContactsPersistenceManager for contact counting
        return ContactsPersistenceManager.shared.getContactsCount()
    }
    
    func getRecentPhotos(limit: Int = 2) -> [SafePhotoData] {
        return Array(photos.sorted { $0.dateAdded > $1.dateAdded }.prefix(limit))
    }
    
    // MARK: - Video Management
    func saveVideo(videoData: Data, fileName: String? = nil, duration: Double? = nil) -> SafeVideoData? {
        let actualFileName = fileName ?? "video_\(UUID().uuidString).mp4"
        logger.info("💾 Saving video to SafeStorageManager - FileName: \(actualFileName)")
        
        do {
            // Save video to file system and generate thumbnail
            let result = try FileSystemStorageManager.saveVideo(videoData, fileName: actualFileName)
            
            // Extract video duration if not provided
            let videoDuration = duration ?? FileSystemStorageManager.extractVideoDuration(from: result.videoURL)
            logger.debug("⏱️ Video duration: \(String(format: "%.2f", videoDuration))s")
            
            // Create local model with video and thumbnail URLs
            let video = SafeVideoData(
                videoURL: result.videoURL,
                thumbnailURL: result.thumbnailURL,
                fileName: actualFileName,
                fileSize: Int64(videoData.count),
                duration: videoDuration
            )
            
            videos.append(video)
            logger.debug("🎥 Added video to local collection - Total videos: \(self.videos.count)")
            
            // Save metadata
            saveVideosMetadata()
            
            logger.info("✅ Video saved successfully to SafeStorageManager")
            return video
            
        } catch {
            logger.error("❌ Error saving video to SafeStorageManager: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveVideoAsync(videoData: Data, fileName: String? = nil, duration: Double? = nil) async -> SafeVideoData? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = self?.saveVideo(videoData: videoData, fileName: fileName, duration: duration)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    func loadAllVideos() -> [SafeVideoData] {
        return videos.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    func deleteVideo(_ video: SafeVideoData) {
        do {
            // Delete from file system
            try FileSystemStorageManager.deleteVideoFiles(
                videoURL: video.videoURL,
                thumbnailURL: video.thumbnailURL
            )
            
            // Remove from local array
            videos.removeAll { $0.id == video.id }
            
            // Save updated metadata
            saveVideosMetadata()
            
        } catch {
            print("Error deleting video: \(error)")
        }
    }
    
    func deleteVideos(_ videosToDelete: [SafeVideoData]) {
        for video in videosToDelete {
            deleteVideo(video)
        }
    }
    
    func getRecentVideos(limit: Int = 2) -> [SafeVideoData] {
        return Array(videos.sorted { $0.dateAdded > $1.dateAdded }.prefix(limit))
    }
    
    func getRecentDocuments(limit: Int = 2) -> [SafeDocumentData] {
        return Array(documents.sorted { $0.dateAdded > $1.dateAdded }.prefix(limit))
    }
    
    private func loadVideos() {
        logger.info("📖 Loading videos from metadata")
        
        do {
            guard FileManager.default.fileExists(atPath: videosMetadataURL.path) else {
                logger.debug("ℹ️ No videos metadata file found, starting with empty collection")
                videos = []
                return
            }
            
            let data = try Data(contentsOf: videosMetadataURL)
            logger.debug("📖 Videos metadata file size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
            let metadata = try JSONDecoder().decode([SafeVideoMetadata].self, from: data)
            
            videos = metadata.compactMap { meta in
                // Migration logic: handle both new format (relative paths) and old format (absolute paths)
                let videoURL: URL
                let thumbnailURL: URL?
                
                if let videoFileName = meta.videoFileName {
                    // New format: use relative filenames and construct full paths
                    videoURL = FileSystemStorageManager.videosDirectory.appendingPathComponent(videoFileName)
                    thumbnailURL = meta.thumbnailFileName.map { 
                        FileSystemStorageManager.thumbnailsDirectory.appendingPathComponent($0) 
                    }
                    logger.debug("📱 Using new relative path format for video: \(videoFileName)")
                } else if let oldVideoPath = meta.videoURL {
                    // Legacy format: extract filename from old absolute path
                    let videoFileName = URL(fileURLWithPath: oldVideoPath).lastPathComponent
                    videoURL = FileSystemStorageManager.videosDirectory.appendingPathComponent(videoFileName)
                    
                    if let oldThumbnailPath = meta.thumbnailURL {
                        let thumbnailFileName = URL(fileURLWithPath: oldThumbnailPath).lastPathComponent
                        thumbnailURL = FileSystemStorageManager.thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
                    } else {
                        thumbnailURL = nil
                    }
                    logger.debug("🔄 Migrated from absolute path for video: \(videoFileName)")
                } else {
                    logger.error("❌ Invalid metadata entry - no valid path found for video ID: \(meta.id)")
                    return nil
                }
                
                return SafeVideoData(
                    id: UUID(uuidString: meta.id) ?? UUID(),
                    videoURL: videoURL,
                    thumbnailURL: thumbnailURL,
                    fileName: meta.fileName,
                    fileSize: meta.fileSize,
                    duration: meta.duration,
                    dateAdded: meta.dateAdded,
                    createdAt: meta.createdAt,
                    modifiedAt: meta.modifiedAt
                )
            }
            
            logger.info("✅ Successfully loaded \(self.videos.count) videos from metadata")
            
            // Check if we loaded any legacy data and need to migrate
            let hasLegacyData = metadata.contains { $0.videoFileName == nil && $0.videoURL != nil }
            if hasLegacyData {
                logger.info("🔄 Detected legacy absolute paths, migrating to new relative path format...")
                saveVideosMetadata()  // Save in new format
                logger.info("✅ Migration completed successfully")
            }
            
        } catch {
            logger.error("❌ Error loading videos: \(error.localizedDescription)")
            videos = []
        }
    }
    
    // MARK: - Document Management
    func saveDocument(documentData: Data, fileName: String, fileExtension: String? = nil, mimeType: String? = nil) -> SafeDocumentData? {
        let actualFileName = fileName
        logger.info("💾 Saving document to SafeStorageManager - FileName: \(actualFileName)")
        
        do {
            // Save document to file system
            let documentURL = try FileSystemStorageManager.saveDocument(documentData, fileName: actualFileName)
            
            // Create local model
            let document = SafeDocumentData(
                documentURL: documentURL,
                fileName: actualFileName,
                fileSize: Int64(documentData.count),
                fileExtension: fileExtension,
                mimeType: mimeType
            )
            
            documents.append(document)
            logger.debug("📄 Added document to local collection - Total documents: \(self.documents.count)")
            
            // Save metadata
            saveDocumentsMetadata()
            
            logger.info("✅ Document saved successfully to SafeStorageManager")
            return document
            
        } catch {
            logger.error("❌ Error saving document to SafeStorageManager: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveDocumentAsync(documentData: Data, fileName: String, fileExtension: String? = nil, mimeType: String? = nil) async -> SafeDocumentData? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = self?.saveDocument(documentData: documentData, fileName: fileName, fileExtension: fileExtension, mimeType: mimeType)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    func loadAllDocuments() -> [SafeDocumentData] {
        return documents.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    func deleteDocument(_ document: SafeDocumentData) {
        do {
            // Delete from file system
            try FileSystemStorageManager.deleteFile(at: document.documentURL)
            
            // Remove from local array
            documents.removeAll { $0.id == document.id }
            
            // Save updated metadata
            saveDocumentsMetadata()
            
        } catch {
            print("Error deleting document: \(error)")
        }
    }
    
    func deleteDocuments(_ documentsToDelete: [SafeDocumentData]) {
        for document in documentsToDelete {
            deleteDocument(document)
        }
    }
    
    private func saveDocumentsMetadata() {
        logger.debug("💾 Saving documents metadata - Count: \(self.documents.count)")
        
        do {
            let metadata = documents.map { document in
                SafeDocumentMetadata(
                    id: document.id.uuidString,
                    documentFileName: document.documentURL.lastPathComponent,
                    fileName: document.fileName,
                    fileSize: document.fileSize,
                    fileExtension: document.fileExtension,
                    mimeType: document.mimeType,
                    dateAdded: document.dateAdded,
                    createdAt: document.createdAt,
                    modifiedAt: document.modifiedAt
                )
            }
            
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: documentsMetadataURL)
            
            logger.debug("✅ Documents metadata saved successfully - Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
        } catch {
            logger.error("❌ Error saving documents metadata: \(error.localizedDescription)")
        }
    }
    
    private func loadDocuments() {
        logger.info("📖 Loading documents from metadata")
        
        do {
            guard FileManager.default.fileExists(atPath: documentsMetadataURL.path) else {
                logger.debug("ℹ️ No documents metadata file found, starting with empty collection")
                documents = []
                return
            }
            
            let data = try Data(contentsOf: documentsMetadataURL)
            logger.debug("📖 Documents metadata file size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
            let metadata = try JSONDecoder().decode([SafeDocumentMetadata].self, from: data)
            
            documents = metadata.compactMap { meta in
                // Migration logic: handle both new format (relative paths) and old format (absolute paths)
                let documentURL: URL
                
                if let documentFileName = meta.documentFileName {
                    // New format: use relative filenames and construct full paths
                    documentURL = FileSystemStorageManager.documentsStorageDirectory.appendingPathComponent(documentFileName)
                    logger.debug("📱 Using new relative path format for document: \(documentFileName)")
                } else if let oldDocumentPath = meta.documentURL {
                    // Legacy format: extract filename from old absolute path
                    let documentFileName = URL(fileURLWithPath: oldDocumentPath).lastPathComponent
                    documentURL = FileSystemStorageManager.documentsStorageDirectory.appendingPathComponent(documentFileName)
                    logger.debug("🔄 Migrated from absolute path for document: \(documentFileName)")
                } else {
                    logger.error("❌ Invalid metadata entry - no valid path found for document ID: \(meta.id)")
                    return nil
                }
                
                return SafeDocumentData(
                    id: UUID(uuidString: meta.id) ?? UUID(),
                    documentURL: documentURL,
                    fileName: meta.fileName,
                    fileSize: meta.fileSize,
                    fileExtension: meta.fileExtension,
                    mimeType: meta.mimeType,
                    dateAdded: meta.dateAdded,
                    createdAt: meta.createdAt,
                    modifiedAt: meta.modifiedAt
                )
            }
            
            logger.info("✅ Successfully loaded \(self.documents.count) documents from metadata")
            
            // Check if we loaded any legacy data and need to migrate
            let hasLegacyData = metadata.contains { $0.documentFileName == nil && $0.documentURL != nil }
            if hasLegacyData {
                logger.info("🔄 Detected legacy absolute paths, migrating to new relative path format...")
                saveDocumentsMetadata()  // Save in new format
                logger.info("✅ Migration completed successfully")
            }
            
        } catch {
            logger.error("❌ Error loading documents: \(error.localizedDescription)")
            documents = []
        }
    }
}
