import SwiftUI

struct SwipedPhotoModel: Identifiable {
    let id = UUID()
    let sections: [AICleanServiceSection]
    let type: ScanItemType
}
