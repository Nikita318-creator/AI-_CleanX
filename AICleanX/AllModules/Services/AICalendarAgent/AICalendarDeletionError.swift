enum AICalendarDeletionError: Error {
    case noPermission
    case eventNotFound
    case cannotDelete(reason: String)
    case systemError(Error)
    
    var localizedDescription: String {
        switch self {
        case .noPermission: return "No permission to access calendar"
        case .eventNotFound: return "Event not found in calendar"
        case .cannotDelete(let reason): return reason
        case .systemError(let error): return "System error: \(error.localizedDescription)"
        }
    }
    
    var isUserActionRequired: Bool {
        if case .cannotDelete = self { return true }
        return false
    }
}
