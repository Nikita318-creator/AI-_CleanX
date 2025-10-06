enum ContactCategory: String, CaseIterable {
    case allContacts = "All contacts"
    case duplicates = "Duplicates"
    case incomplete = "Incomplete"
    
    var systemImage: String {
        switch self {
        case .allContacts: return "person.2.fill"
        case .duplicates: return "person.2.badge.minus"
        case .incomplete: return "person.badge.clock"
        }
    }
}
