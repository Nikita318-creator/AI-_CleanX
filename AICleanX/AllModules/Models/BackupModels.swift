import Foundation

// MARK: - Backup Item Model
struct BackupItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let date: Date
    let contactsCount: Int
    let size: String
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var dayOfWeek: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var dateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return timeString
        } else if calendar.isDateInYesterday(date) {
            return timeString
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
