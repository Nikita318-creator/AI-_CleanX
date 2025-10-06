
import SwiftUI

// MARK: - Legacy Data Model (for backward compatibility)
struct CalendarEvent: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let source: String
    let date: Date
    let eventIdentifier: String // Уникальный идентификатор события из системного календаря
    var isWhiteListed: Bool = false
    var isMarkedAsSpam: Bool = false
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    // Извлекает оригинальный eventIdentifier из составного ключа
    var originalEventIdentifier: String {
        if eventIdentifier.contains("_") {
            return String(eventIdentifier.split(separator: "_").first ?? "")
        }
        return eventIdentifier
    }
    
    // Инициализатор для создания из SystemCalendarEvent
    init(from systemEvent: AICalendarSystemEvent) {
        self.title = systemEvent.title
        self.source = systemEvent.calendar // Используем calendar как source
        self.date = systemEvent.startDate // Используем startDate как date
        // Создаем уникальный идентификатор из eventIdentifier + startDate для повторяющихся событий
        self.eventIdentifier = "\(systemEvent.eventIdentifier)_\(systemEvent.startDate.timeIntervalSince1970)"
        self.isWhiteListed = systemEvent.isWhiteListed
        self.isMarkedAsSpam = systemEvent.isMarkedAsSpam
    }
    
    // Обычный инициализатор
    init(title: String, source: String, date: Date, eventIdentifier: String = UUID().uuidString, isWhiteListed: Bool = false, isMarkedAsSpam: Bool = false) {
        self.title = title
        self.source = source
        self.date = date
        self.eventIdentifier = eventIdentifier
        self.isWhiteListed = isWhiteListed
        self.isMarkedAsSpam = isMarkedAsSpam
    }
}
