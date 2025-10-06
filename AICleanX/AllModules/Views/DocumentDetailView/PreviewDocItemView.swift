import QuickLook
import SwiftUI

class PreviewDocItemView: NSObject, QLPreviewItem {
    let fileURL: URL
    
    init(url: URL) {
        self.fileURL = url
        super.init()
    }
    
    var previewItemURL: URL? {
        fileURL
    }
    
    var previewItemTitle: String? {
        fileURL.lastPathComponent
    }
}
