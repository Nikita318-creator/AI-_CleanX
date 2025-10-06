import Photos
import UIKit

extension PHAsset {
    var fakeSize: Double {
        switch mediaType {
        case .image:
            return Double(pixelHeight * pixelWidth) / 4848366.3
        case .video:
            return Double(pixelHeight * pixelWidth) * duration / 1403107.5
        default:
            return 0
        }
    }

    var megabytesOnDisk: Double {
        let resources = PHAssetResource.assetResources(for: self)
        var bytesOnDisk: Int64 = 0
        if let resource = resources.first {
            let unsignedInt64 = resource.value(forKey: "fileSize") as? CLong
            bytesOnDisk = Int64(bitPattern: UInt64(unsignedInt64!))
        }
        return Double(bytesOnDisk) / Double(1048576)
    }

    func getImage(
        imageManager: PHImageManager,
        size: CGSize = PHImageManagerMaximumSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: self,
            targetSize: size,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    func getVideo(imageManager: PHImageManager, completion: @escaping (AVPlayerItem?) -> Void) {
        let requestOptions = PHVideoRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        imageManager.requestPlayerItem(
            forVideo: self,
            options: requestOptions
        ) { item, _  in
            completion(item)
        }
    }
}

extension PHAuthorizationStatus {
    var name: String {
        switch self {
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .authorized:
            return "authorized"
        case .limited:
            return "limited"
        @unknown default:
            return "denied"
        }
    }
}
