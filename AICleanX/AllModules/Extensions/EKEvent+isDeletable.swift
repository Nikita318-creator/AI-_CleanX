import EventKit

extension EKEvent {
    func isDeletable() -> Bool {
        guard calendar.allowsContentModifications else { return false }
        
        if calendar.type == .birthday || calendar.type == .subscription {
            return false
        }
        
        if self.organizer != nil, calendar.type == .calDAV {
            return false
        }
        
        return true
    }
    
    func deletionRestrictionReason() -> String {
        if !calendar.allowsContentModifications {
            return "'\(calendar.title)' calendar is read-only and doesn't allow modifications."
        }
        
        if calendar.type == .subscription {
            return "This subscription calendar cannot be deleted. To remove these events, you must delete the source account from your device settings."
        }
        
        if calendar.type == .birthday {
            return "Birthday events cannot be deleted from the calendar."
        }
        
        if let organizer = self.organizer, calendar.type == .calDAV {
            let organizerName = organizer.name ?? "another user"
            return "This event is from a shared calendar and cannot be deleted. It was organized by \(organizerName)."
        }
        
        return "This event cannot be deleted due to calendar restrictions."
    }
}
