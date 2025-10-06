import Photos
import UIKit

struct AICleanServiceProgress {
    static let startImages = Self(type: .image, index: 0, value: 0, isFinished: false)
    static let startVideos = Self(type: .video, index: 0, value: 0, isFinished: false)

    let type: AICleanServiceType
    let index: Int
    let value: Double
    let isFinished: Bool
}
