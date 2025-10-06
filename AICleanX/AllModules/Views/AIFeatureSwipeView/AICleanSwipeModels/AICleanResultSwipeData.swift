import Foundation

struct AICleanResultSwipeData: Identifiable {
    let id = UUID()
    let keptCount: Int
    let deletedCount: Int
    let keptPhotos: [String]
    let deletedPhotos: [String]
}
