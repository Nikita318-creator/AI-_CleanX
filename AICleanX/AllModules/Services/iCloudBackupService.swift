import Foundation
import CloudKit
import Combine
import os.log
import UIKit

/// Service for backing up contacts to iCloud using CloudKit
final class iCloudBackupService: ObservableObject {
    private let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "iCloudBackup")
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    // MARK: - Constants
    private enum Constants {
        static let recordType = "ContactsBackup"
        static let contactsDataKey = "contactsData"
        static let contactsCountKey = "contactsCount"
        static let backupDateKey = "backupDate"
        static let appVersionKey = "appVersion"
        static let deviceIDKey = "deviceID"
    }
    
    // MARK: - Published Properties
    @Published var isBackingUp = false
    @Published var lastError: Error?
    @Published var backupHistory: [iCloudBackupItem] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Use the default container for the app
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        
        logger.info("🏗️ iCloudBackupService initialized")
        
        // Check iCloud availability
        checkiCloudAccountStatus()
    }
    
    // MARK: - Public Methods
    
    /// Backs up contacts to iCloud
    /// - Parameter contacts: Array of contacts to backup
    /// - Returns: Success indicator
    @MainActor
    func backupContacts(_ contacts: [ContactData]) async -> Bool {
        guard !isBackingUp else {
            logger.warning("⚠️ Backup already in progress")
            return false
        }
        
        logger.info("🚀 Starting iCloud backup for \(contacts.count) contacts")
        isBackingUp = true
        lastError = nil
        
        do {
            // Create backup record
            let record = try await createBackupRecord(contacts: contacts)
            
            // Save to iCloud
            _ = try await privateDatabase.save(record)
            
            BackupService.shared.recordSuccessfulBackup()
            
            let backupItem = iCloudBackupItem(
                id: record.recordID.recordName,
                date: Date(),
                contactsCount: contacts.count,
                size: calculateBackupSize(contacts),
                recordID: record.recordID
            )
            backupHistory.insert(backupItem, at: 0)
            
            logger.info("✅ Successfully backed up \(contacts.count) contacts to iCloud")
            isBackingUp = false
            return true
            
        } catch {
            logger.error("❌ Failed to backup contacts to iCloud: \(error.localizedDescription)")
            lastError = error
            isBackingUp = false
            return false
        }
    }
    
    /// Fetches backup history from iCloud
    @MainActor
    func fetchBackupHistory() async {
        logger.info("📖 Fetching backup history from iCloud")
        
        let query = CKQuery(recordType: Constants.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: Constants.backupDateKey, ascending: false)]
        
        do {
            let result = try await privateDatabase.records(matching: query)
            let items = result.matchResults.compactMap { (recordID, result) -> iCloudBackupItem? in
                switch result {
                case .success(let record):
                    return iCloudBackupItem(from: record)
                case .failure(let error):
                    logger.error("❌ Failed to process backup record \(recordID): \(error.localizedDescription)")
                    return nil
                }
            }
            
            backupHistory = items
            logger.info("✅ Loaded \(items.count) backup items from iCloud")
            
        } catch {
            logger.error("❌ Failed to fetch backup history: \(error.localizedDescription)")
            lastError = error
        }
    }
    
    /// Deletes a backup from iCloud
    /// - Parameter backupItem: The backup item to delete
    @MainActor
    func deleteBackup(_ backupItem: iCloudBackupItem) async -> Bool {
        logger.info("🗑️ Deleting backup: \(backupItem.id)")
        
        do {
            _ = try await privateDatabase.deleteRecord(withID: backupItem.recordID)
            backupHistory.removeAll { $0.id == backupItem.id }
            logger.info("✅ Successfully deleted backup")
            return true
        } catch {
            logger.error("❌ Failed to delete backup: \(error.localizedDescription)")
            lastError = error
            return false
        }
    }
    
    @MainActor
    func restoreContacts(from backupItem: iCloudBackupItem) async -> [ContactData]? {
        let recordID = backupItem.recordID
        logger.info("Restore contacts from record ID: \(recordID.recordName)")

        do {
            let record = try await privateDatabase.record(for: recordID)
            guard let contactsData = record[Constants.contactsDataKey] as? Data else {
                logger.error("❌ No contacts data found in record.")
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let contacts = try decoder.decode([ContactData].self, from: contactsData)
            logger.info("✅ Successfully restored \(contacts.count) contacts.")
            return contacts
        } catch {
            logger.error("❌ Failed to restore contacts from iCloud record: \(error.localizedDescription)")
            lastError = error
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func checkiCloudAccountStatus() {
        container.accountStatus { [weak self] accountStatus, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch accountStatus {
                case .available:
                    self.logger.info("✅ iCloud account is available")
                case .noAccount:
                    self.logger.warning("⚠️ No iCloud account configured")
                case .restricted:
                    self.logger.warning("⚠️ iCloud account is restricted")
                case .couldNotDetermine:
                    self.logger.error("❌ Could not determine iCloud account status")
                case .temporarilyUnavailable:
                    self.logger.warning("⚠️ iCloud account is temporarily unavailable")
                @unknown default:
                    self.logger.error("❌ Unknown iCloud account status")
                }
                
                if let error = error {
                    self.logger.error("❌ iCloud account status error: \(error.localizedDescription)")
                    self.lastError = error
                }
            }
        }
    }
    
    private func createBackupRecord(contacts: [ContactData]) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: Constants.recordType, recordID: recordID)
        
        // Encode contacts data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let contactsData = try encoder.encode(contacts)
        
        // Set record fields
        record[Constants.contactsDataKey] = contactsData
        record[Constants.contactsCountKey] = contacts.count
        record[Constants.backupDateKey] = Date()
        record[Constants.appVersionKey] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        record[Constants.deviceIDKey] = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        return record
    }
    
    private func calculateBackupSize(_ contacts: [ContactData]) -> String {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(contacts)
            let bytes = Double(data.count)
            
            if bytes < 1024 {
                return "\(Int(bytes)) B"
            } else if bytes < 1024 * 1024 {
                return String(format: "%.1f KB", bytes / 1024)
            } else {
                return String(format: "%.1f MB", bytes / (1024 * 1024))
            }
        } catch {
            return "Unknown"
        }
    }
}

// MARK: - iCloudBackupItem Model
struct iCloudBackupItem: Identifiable, Hashable {
    let id: String
    let date: Date
    let contactsCount: Int
    let size: String
    let recordID: CKRecord.ID
    
    init(id: String, date: Date, contactsCount: Int, size: String, recordID: CKRecord.ID) {
        self.id = id
        self.date = date
        self.contactsCount = contactsCount
        self.size = size
        self.recordID = recordID
    }
    
    init?(from record: CKRecord) {
        guard let backupDate = record["backupDate"] as? Date,
              let contactsCount = record["contactsCount"] as? Int else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.date = backupDate
        self.contactsCount = contactsCount
        self.recordID = record.recordID
        
        // Calculate size from data if available
        if let contactsData = record["contactsData"] as? Data {
            let bytes = Double(contactsData.count)
            if bytes < 1024 {
                self.size = "\(Int(bytes)) B"
            } else if bytes < 1024 * 1024 {
                self.size = String(format: "%.1f KB", bytes / 1024)
            } else {
                self.size = String(format: "%.1f MB", bytes / (1024 * 1024))
            }
        } else {
            self.size = "Unknown"
        }
    }
    
    // MARK: - Computed Properties
    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
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
}
