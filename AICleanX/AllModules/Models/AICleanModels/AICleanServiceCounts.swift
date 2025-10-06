import Photos
import UIKit

class AICleanServiceCounts<Element: Numeric> {
    var similar: Element
    var duplicates: Element
    var blurred: Element
    var screenshots: Element
    var videos: Element
    var audio: Element
    var total: Element

    private let lock = NSLock()

    init(
        similar: Element = 0,
        duplicates: Element = 0,
        blurred: Element = 0,
        screenshots: Element = 0,
        videos: Element = 0,
        audio: Element = 0,
        total: Element = 0
    ) {
        self.similar = similar
        self.duplicates = duplicates
        self.blurred = blurred
        self.screenshots = screenshots
        self.videos = videos
        self.audio = audio
        self.total = total
    }

    func set(count: Element, for type: AICleanServiceType) {
        lock.lock()
        switch type {
        case .image(let imageType):
            switch imageType {
            case .similar:
                similar = (count)
            case .duplicates:
                duplicates = count
            case .blurred:
                blurred = count
            case .screenshots:
                screenshots = count
            }
        case .video:
            videos = count
        case .audio:
            audio = count
        }

        total = similar + duplicates + blurred + screenshots + videos + audio
        lock.unlock()
    }

    func add(count: Element, to type: AICleanServiceType) {
        lock.lock()
        switch type {
        case .image(let imageType):
            switch imageType {
            case .similar:
                let accumulated = similar
                similar = accumulated + count
            case .duplicates:
                let accumulated = duplicates
                duplicates = accumulated + count
            case .blurred:
                let accumulated = blurred
                blurred = accumulated + count
            case .screenshots:
                let accumulated = screenshots
                screenshots = accumulated + count
            }
        case .video:
            let accumulated = videos
            videos = accumulated + count
        case .audio:
            let accumulated = audio
            audio = accumulated + count
        }

        total = similar + duplicates + blurred + screenshots + videos + audio
        lock.unlock()
    }
}
