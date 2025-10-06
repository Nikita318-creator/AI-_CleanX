import Photos

enum AICleanServiceType: Equatable {
    static let image = Self.image(.duplicates)

    enum ImageType {
        case similar
        case duplicates
        case blurred
        case screenshots
    }

    case image(ImageType)
    case video
    case audio
}
