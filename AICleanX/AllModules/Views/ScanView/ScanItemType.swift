enum ScanItemType: Identifiable, Hashable {
    case contacts
    case calendar
    case similar
    case duplicates
    case blurred
    case screenshots
    case videos
    
    var id: String {
        switch self {
        case .contacts: return "contacts"
        case .calendar: return "calendar"
        case .similar: return "similar"
        case .duplicates: return "duplicates"
        case .blurred: return "blurred"
        case .screenshots: return "screenshots"
        case .videos: return "videos"
        }
    }
    
    var title: String {
        switch self {
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .similar: return "Similar Photos"
        case .duplicates: return "Duplicates"
        case .blurred: return "Blurry Photos"
        case .screenshots: return "Screenshots"
        case .videos: return "Videos"
        }
    }
}
