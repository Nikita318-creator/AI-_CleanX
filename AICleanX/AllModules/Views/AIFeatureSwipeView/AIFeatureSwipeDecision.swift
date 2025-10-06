import SwiftUI
import Photos

enum AIFeatureSwipeDecision: String, CaseIterable {
    case none
    case keep
    case delete
    
    var color: Color {
        switch self {
        case .none:
            return .clear
        case .keep:
            return .green
        case .delete:
            return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .none:
            return ""
        case .keep:
            return "checkmark"
        case .delete:
            return "xmark"
        }
    }
}
