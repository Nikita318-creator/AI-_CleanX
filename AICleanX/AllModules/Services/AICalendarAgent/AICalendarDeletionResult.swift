struct AICalendarDeletionResult {
    let deletedCount: Int
    let totalCount: Int
    let failedEvents: [(AICalendarSystemEvent, AICalendarDeletionError)]
    
    var hasFailures: Bool { !failedEvents.isEmpty }
    var cannotDeleteEvents: [(AICalendarSystemEvent, AICalendarDeletionError)] { failedEvents.filter { $0.1.isUserActionRequired } }
    var hasCannotDeleteEvents: Bool { !cannotDeleteEvents.isEmpty }
}
