import Photos
import UIKit

struct AICleanServicePreviews {
    let similar: UIImage?
    let duplicates: UIImage?
    let blurred: UIImage?
    let screenshots: UIImage?
    let videos: UIImage?

    init(
        _similar: UIImage?,
        _duplicates: UIImage?,
        _blurred: UIImage?,
        _screenshots: UIImage?,
        _videos: UIImage?
    ) {
        similar = _similar
        duplicates = _duplicates
        blurred = _blurred
        screenshots = _screenshots
        videos = _videos
    }
}
