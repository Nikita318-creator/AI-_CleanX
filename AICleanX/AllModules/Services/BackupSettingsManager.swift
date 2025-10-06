import Foundation
import Combine
import os.log

// MARK: - Constants & Utilities

/// Keys for UserDefaults to manage backup settings.
private enum BackupSettingsKey: String {
    case isAutoBackupEnabled = "isAutoBackupEnabled_v1"
    case lastBackupDate = "lastBackupDate_v1"
    case totalBackupsCount = "totalBackupsCount_v1"
}

private extension Date {
    /// Formats a date for display as a backup record.
    func backupDisplayText() -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            return "Today at \(Date.timeFormatter.string(from: self))"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday at \(Date.timeFormatter.string(from: self))"
        } else {
            return Date.backupDateFormatter.string(from: self)
        }
    }
}

private extension Date {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - BackupService

/// Manages all backup-related user preferences and settings.
final class BackupService: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "BackupSettings")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Published Properties
    
    @Published var isAutoBackupEnabled: Bool {
        didSet {
            userDefaults.set(isAutoBackupEnabled, forKey: BackupSettingsKey.isAutoBackupEnabled.rawValue)
            logger.info("🔄 Auto backup setting changed to: \(self.isAutoBackupEnabled)")
        }
    }
    
    @Published var lastBackupDate: Date? {
        didSet {
            userDefaults.set(lastBackupDate, forKey: BackupSettingsKey.lastBackupDate.rawValue)
            logger.info("📅 Last backup date updated: \(self.lastBackupDate?.formatted() ?? "nil")")
        }
    }
    
    @Published var totalBackupsCount: Int {
        didSet {
            userDefaults.set(totalBackupsCount, forKey: BackupSettingsKey.totalBackupsCount.rawValue)
            logger.info("📊 Total backups count updated: \(self.totalBackupsCount)")
        }
    }
    
    // MARK: - Computed Property
    
    var lastBackupDisplayText: String {
        return lastBackupDate?.backupDisplayText() ?? "Never"
    }
    
    // MARK: - Singleton & Initialization
    
    static let shared = BackupService()
    
    private init() {
        self.isAutoBackupEnabled = userDefaults.bool(forKey: BackupSettingsKey.isAutoBackupEnabled.rawValue)
        self.lastBackupDate = userDefaults.object(forKey: BackupSettingsKey.lastBackupDate.rawValue) as? Date
        self.totalBackupsCount = userDefaults.integer(forKey: BackupSettingsKey.totalBackupsCount.rawValue)
        
        logInitialization()
    }
    
    // MARK: - Public Methods
    
    func recordSuccessfulBackup() {
        totalBackupsCount += 1
        lastBackupDate = Date()
        logger.info("✅ Backup recorded successfully")
    }
    
    func resetSettings() {
        isAutoBackupEnabled = false
        lastBackupDate = nil
        totalBackupsCount = 0
        
        userDefaults.removeObject(forKey: BackupSettingsKey.isAutoBackupEnabled.rawValue)
        userDefaults.removeObject(forKey: BackupSettingsKey.lastBackupDate.rawValue)
        userDefaults.removeObject(forKey: BackupSettingsKey.totalBackupsCount.rawValue)
        
        logger.info("🧹 Backup settings reset")
    }
    
    // MARK: - Private Helpers
    
    private func logInitialization() {
        logger.info("🏗️ BackupService initialized")
        logger.info("  📱 Auto backup enabled: \(self.isAutoBackupEnabled)")
        logger.info("  📅 Last backup: \(self.lastBackupDate?.formatted() ?? "None")")
        logger.info("  📊 Total backups: \(self.totalBackupsCount)")
    }
}
