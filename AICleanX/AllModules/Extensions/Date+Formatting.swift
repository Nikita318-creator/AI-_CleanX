import Foundation

extension Date {
    /// Форматирует дату в строку вида "12 Mar 2023"
    func formatAsShortDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: self)
    }
    
    /// Форматирует дату в строку вида "12 марта 2023" (русская локализация)
    func formatAsShortDateRussian() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: self)
    }
    
    /// Форматирует дату в строку с учетом текущей локали устройства
    func formatAsShortDateLocalized() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
    
    /// Форматирует дату в строку вида "Today", "Yesterday" или "12 Mar 2023"
    func formatAsRelativeShortDate() -> String {
        let calendar = Calendar.current        
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            return formatAsShortDate()
        }
    }
}
