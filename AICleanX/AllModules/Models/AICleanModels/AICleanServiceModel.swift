import Photos
import UIKit

class AICleanServiceModel: Hashable {
    enum CustomError: Error {
        case noSelf
    }

    static func == (lhs: AICleanServiceModel, rhs: AICleanServiceModel) -> Bool {
        lhs.asset === rhs.asset
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(asset)
    }

    let imageManager: PHCachingImageManager
    let asset: PHAsset
    let index: Int
    var equality: Double = 0
    var similarity = 0

    init(imageManager: PHCachingImageManager, asset: PHAsset, index: Int) {
        self.imageManager = imageManager
        self.asset = asset
        self.index = index
    }

    func getImage(size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        self.imageManager.requestImage(
            for: self.asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            completion(image)
        }
    }
}
