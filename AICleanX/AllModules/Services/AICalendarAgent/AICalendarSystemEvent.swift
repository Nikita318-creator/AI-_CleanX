import Foundation
import EventKit
import Combine

struct AICalendarSystemEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendar: String
    let location: String?
    let notes: String?
    var isMarkedAsSpam: Bool
    var isWhiteListed: Bool
    
    init(from ekEvent: EKEvent, isWhitelisted: Bool = false) {
        self.id = UUID()
        self.eventIdentifier = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendar = ekEvent.calendar?.title ?? "Unknown Calendar"
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.isMarkedAsSpam = (ekEvent.notes ?? "").contains(AICalendarAgent.Constants.spamMarker)
        self.isWhiteListed = isWhitelisted
    }
    
    init(id: UUID = UUID(), eventIdentifier: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendar: String, location: String? = nil, notes: String? = nil, isMarkedAsSpam: Bool = false, isWhiteListed: Bool = false) {
        self.id = id
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendar = calendar
        self.location = location
        self.notes = notes
        self.isMarkedAsSpam = isMarkedAsSpam
        self.isWhiteListed = isWhiteListed
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = isAllDay ? "d MMM yyyy" : "d MMM yyyy, HH:mm"
        return formatter.string(from: startDate)
    }
    
    var formattedTimeRange: String {
        if isAllDay {
            return "All day"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}
