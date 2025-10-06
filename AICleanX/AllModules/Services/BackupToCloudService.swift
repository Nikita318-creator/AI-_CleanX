import Foundation

/// Менеджер для сохранения и загрузки истории бэкапов в UserDefaults.
class BackupToCloudService {
    static let shared = BackupToCloudService()
    private let userDefaults = UserDefaults.standard
    private let backupsKey = "iCloudBackupHistory_v1"

    private init() {}

    func saveBackups(_ backups: [BackupItem]) {
        do {
            let encodedData = try JSONEncoder().encode(backups)
            userDefaults.set(encodedData, forKey: backupsKey)
        } catch {
            print("❌ Failed to encode backups history: \(error.localizedDescription)")
        }
    }

    func loadBackups() -> [BackupItem] {
        guard let data = userDefaults.data(forKey: backupsKey) else {
            return []
        }
        
        do {
            let backups = try JSONDecoder().decode([BackupItem].self, from: data)
            return backups
        } catch {
            print("❌ Failed to decode backups history: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteBackup(withId id: String) {
        var backups = loadBackups()
        
        if let index = backups.firstIndex(where: { $0.id.uuidString == id }) {
            backups.remove(at: index)
            saveBackups(backups)
            print("✅ Backup with ID \(id) successfully deleted.")
        } else {
            print("❌ Backup with ID \(id) not found in history.")
        }
    }
}
