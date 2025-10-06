import Foundation
import os.log

/// A reliable persistence manager for contacts using UserDefaults and JSON encoding
/// This avoids Core Data issues while providing proper data persistence
class ContactsPersistenceManager {
    private let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "ContactsPersistence")
    private let userDefaults = UserDefaults.standard
    private let contactsKey = "SavedContacts_v1"
    
    static let shared = ContactsPersistenceManager()
    
    private init() {
        logger.info("🏗️ ContactsPersistenceManager initialized")
    }
    
    // MARK: - CRUD Operations
    
    func saveContacts(_ contacts: [ContactData]) {
        logger.info("💾 Saving \(contacts.count) contacts to persistent storage")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encodedData = try encoder.encode(contacts)
            userDefaults.set(encodedData, forKey: contactsKey)
            logger.info("✅ Successfully saved contacts to UserDefaults")
        } catch {
            logger.error("❌ Failed to encode contacts: \(error.localizedDescription)")
        }
    }
    
    func loadContacts() -> [ContactData] {
        logger.info("📖 Loading contacts from persistent storage")
        
        guard let data = userDefaults.data(forKey: contactsKey) else {
            logger.info("ℹ️ No saved contacts found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let contacts = try decoder.decode([ContactData].self, from: data)
            logger.info("✅ Successfully loaded \(contacts.count) contacts")
            return contacts
        } catch {
            logger.error("❌ Failed to decode contacts: \(error.localizedDescription)")
            return []
        }
    }
    
    func addContact(_ contact: ContactData) {
        logger.info("➕ Adding contact: \(contact.fullName)")
        var contacts = loadContacts()
        contacts.append(contact)
        saveContacts(contacts)
    }
    
    func updateContact(_ updatedContact: ContactData) {
        logger.info("📝 Updating contact: \(updatedContact.fullName)")
        var contacts = loadContacts()
        
        if let index = contacts.firstIndex(where: { $0.id == updatedContact.id }) {
            contacts[index] = updatedContact
            saveContacts(contacts)
            logger.info("✅ Contact updated successfully")
        } else {
            logger.error("❌ Contact not found for update")
        }
    }
    
    func deleteContact(withId id: UUID) {
        logger.info("🗑️ Deleting contact with ID: \(id)")
        var contacts = loadContacts()
        contacts.removeAll { $0.id == id }
        saveContacts(contacts)
        logger.info("✅ Contact deleted successfully")
    }
    
    func getContactsCount() -> Int {
        let count = loadContacts().count
        logger.debug("📊 Current contacts count: \(count)")
        return count
    }
    
    func clearAllContacts() {
        logger.info("🧹 Clearing all contacts")
        userDefaults.removeObject(forKey: contactsKey)
    }
}
