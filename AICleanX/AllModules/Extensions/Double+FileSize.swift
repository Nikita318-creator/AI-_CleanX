import Foundation

extension Double {
    /// Форматирует размер в мегабайтах в читаемую строку используя ByteCountFormatter
    func formatAsFileSize() -> String {
        let bytes = Int64(self * 1024 * 1024) // Конвертируем MB в байты
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Кастомный формат с более точным контролем
    func formatAsFileSizeCustom() -> String {
        let bytes = self * 1024 * 1024 // Конвертируем MB в байты
        
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
        }
    }
    
    /// Альтернативный метод с более точным форматированием
    func formatAsFileSizeDetailed() -> String {
        let megabytes = self
        
        if megabytes < 0.001 {
            let kilobytes = megabytes * 1024
            if kilobytes < 0.1 {
                return "< 0.1 KB"
            }
            return String(format: "%.1f KB", kilobytes)
        } else if megabytes < 1024 {
            return String(format: "%.1f MB", megabytes)
        } else {
            let gigabytes = megabytes / 1024
            return String(format: "%.2f GB", gigabytes)
        }
    }
    
    /// Компактный формат без десятичных знаков для небольших размеров
    func formatAsFileSizeCompact() -> String {
        let megabytes = self
        
        if megabytes < 0.1 {
            let kilobytes = megabytes * 1024
            return String(format: "%.0f KB", max(kilobytes, 1))
        } else if megabytes < 1024 {
            if megabytes < 10 {
                return String(format: "%.1f MB", megabytes)
            } else {
                return String(format: "%.0f MB", megabytes)
            }
        } else {
            let gigabytes = megabytes / 1024
            return String(format: "%.1f GB", gigabytes)
        }
    }
}
