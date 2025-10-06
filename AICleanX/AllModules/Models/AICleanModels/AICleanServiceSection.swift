import Photos
import UIKit

struct AICleanServiceSection: Identifiable {
    let id = UUID()
    
    enum Kind {
        case count
        case date(Date?)
        case united(Date?)
    }
    let kind: Kind
    var models: [AICleanServiceModel]
}
