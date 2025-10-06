import Foundation

enum SystemFileErrors: LocalizedError {
    case directoryCreationFailed
    case fileWriteFailed
    case fileReadFailed
    case fileNotFound
    case thumbnailGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "Failed to create storage directory"
        case .fileWriteFailed:
            return "Failed to write file to storage"
        case .fileReadFailed:
            return "Failed to read file from storage"
        case .fileNotFound:
            return "File not found in storage"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        }
    }
}
