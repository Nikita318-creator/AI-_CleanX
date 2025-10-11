import Photos
import UIKit

class AICleanServiceModel: Hashable, Identifiable {
    enum CustomError: Error {
        case noSelf
    }

    // 1. ИСПРАВЛЕНО: Сравнение по стабильному строковому ID
    static func == (lhs: AICleanServiceModel, rhs: AICleanServiceModel) -> Bool {
        return lhs.asset.localIdentifier == rhs.asset.localIdentifier
    }

    // 2. ИСПРАВЛЕНО: Хэширование по стабильному строковому ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(asset.localIdentifier)
    }

    let id: String // Используем let, так как localIdentifier не меняется
    let imageManager: PHCachingImageManager
    let asset: PHAsset
    let index: Int
    var equality: Double = 0
    var similarity = 0

    init(imageManager: PHCachingImageManager, asset: PHAsset, index: Int) {
        self.imageManager = imageManager
        self.asset = asset
        self.index = index
        // 3. ДОБАВЛЕНО: Инициализируем id стабильным значением
        self.id = asset.localIdentifier
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
