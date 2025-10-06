import Foundation
import CoreData
import Combine
import Contacts
import CloudKit
import os.log

@MainActor
class AICleanerContactsViewModel: ObservableObject, ContactViewModelProtocol {
    @Published var contacts: [ContactData] = []
    @Published var systemContacts: [CNContact] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var showingAddContact = false
    @Published var selectedContact: ContactData?
    @Published var errorMessage: String?
    @Published var showingContactPicker = false
    @Published var importedContactsCount = 0
    @Published var showDeleteFromPhoneAlert = false
    
    private var importedCNContacts: [CNContact] = []
    
    private let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "ContactsViewModel")
    private let persistenceManager = ContactsPersistenceManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSearchSubscription()
        loadContacts()
    }
    
    private func setupSearchSubscription() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterContacts()
            }
            .store(in: &cancellables)
    }
    
    var filteredContacts: [ContactData] {
        if searchText.isEmpty {
            return contacts.sorted { $0.firstName.localizedCaseInsensitiveCompare($1.firstName) == .orderedAscending }
        } else {
            return contacts.filter { contact in
                contact.fullName.localizedCaseInsensitiveContains(searchText) ||
                contact.phoneNumber.contains(searchText) ||
                contact.email?.localizedCaseInsensitiveContains(searchText) == true
            }.sorted { $0.firstName.localizedCaseInsensitiveCompare($1.firstName) == .orderedAscending }
        }
    }
    
    func loadContacts() {
        isLoading = true
        logger.info("📖 Loading contacts from persistent storage")
        
        self.contacts = persistenceManager.loadContacts()
        
        logger.info("✅ Successfully loaded \(self.contacts.count) contacts to memory")
        
        // Log some details about loaded contacts
        for (index, contact) in self.contacts.enumerated() {
            logger.debug("📋 Contact \(index + 1): \(contact.fullName) - \(contact.phoneNumber)")
        }
        
        isLoading = false
    }
    
    func addContact(_ contactData: ContactData) {
        logger.info("💾 Adding new contact: \(contactData.fullName)")
        logger.debug("📊 Contact data: firstName=\(contactData.firstName), lastName=\(contactData.lastName), phone=\(contactData.phoneNumber)")
        
        persistenceManager.addContact(contactData)
        self.contacts.append(contactData)
        logger.info("✅ Contact added successfully. Total contacts in memory: \(self.contacts.count)")
    }
    
    func updateContact(_ contactData: ContactData) {
        logger.info("📝 Updating contact: \(contactData.fullName)")
        
        persistenceManager.updateContact(contactData)
        
        // Update local array
        if let index = contacts.firstIndex(where: { $0.id == contactData.id }) {
            contacts[index] = contactData
            logger.info("✅ Contact updated successfully")
        }
    }
    
    func deleteContact(_ contactData: ContactData) {
        logger.info("🗑️ Deleting contact: \(contactData.fullName)")
        
        persistenceManager.deleteContact(withId: contactData.id)
        
        // Remove from local array
        contacts.removeAll { $0.id == contactData.id }
        logger.info("✅ Contact deleted successfully")
    }
    
    func deleteContacts(_ contactsToDelete: [ContactData]) {
        for contact in contactsToDelete {
            deleteContact(contact)
        }
    }
    
    private func filterContacts() {
        // This method is called by the search subscription
        // The actual filtering is done in the computed property
        objectWillChange.send()
    }
    
    // MARK: - Helper Methods
    
    private func validateContactData(_ contactData: ContactData) -> Bool {
        return !contactData.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
               !contactData.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Contact Import Functions
    
    func importContacts(_ cnContacts: [CNContact]) {
        logger.info("📥 Importing \(cnContacts.count) contacts from system")
        
        var importedCount = 0
        var skippedCount = 0
        var validCNContacts: [CNContact] = []
        
        for cnContact in cnContacts {
            let contactData = ContactImportHelper.convertToContactData(cnContact)
            
            // Check if contact already exists (by phone number)
            let exists = contacts.contains { existingContact in
                !contactData.phoneNumber.isEmpty && 
                existingContact.phoneNumber == contactData.phoneNumber
            }
            
            if !exists && !contactData.firstName.isEmpty {
                addContact(contactData)
                validCNContacts.append(cnContact)
                importedCount += 1
            } else {
                skippedCount += 1
                logger.debug("⏭️ Skipped duplicate or invalid contact: \(contactData.fullName)")
            }
        }
        
        importedContactsCount = importedCount
        importedCNContacts = validCNContacts
        
        if importedCount > 0 {
            logger.info("✅ Successfully imported \(importedCount) contacts")
            // Show delete from phone alert
            showDeleteFromPhoneAlert = true
        }
        
        if skippedCount > 0 {
            logger.info("⏭️ Skipped \(skippedCount) duplicate or invalid contacts")
        }
        
        // Show success message
        if importedCount > 0 {
            errorMessage = nil // Clear any previous errors
        }
    }
    
    func clearImportedContactsCount() {
        importedContactsCount = 0
    }
    
    func deleteContactsFromPhone() async {
        logger.info("🗑️ Deleting \(self.importedCNContacts.count) contacts from phone")
        
        let success = await ContactImportHelper.deleteContactsFromPhone(self.importedCNContacts)
        
        await MainActor.run {
            if success {
                logger.info("✅ Successfully deleted contacts from phone")
            } else {
                logger.error("❌ Failed to delete contacts from phone")
                self.errorMessage = "Failed to delete contacts from phone"
            }
            
            // Clear the stored contacts
            self.importedCNContacts.removeAll()
            self.showDeleteFromPhoneAlert = false
        }
    }
    
    func cancelDeleteFromPhone() {
        logger.info("❌ User cancelled deleting contacts from phone")
        self.importedCNContacts.removeAll()
        self.showDeleteFromPhoneAlert = false
    }
    
    // MARK: - UI Helper Methods
    func showAddContact() {
        selectedContact = nil
        showingAddContact = true
    }
    
    func showEditContact(_ contact: ContactData) {
        selectedContact = contact
        showingAddContact = true
    }
    
    func hideAddContact() {
        showingAddContact = false
        selectedContact = nil
    }
    
    func getContactsCount() -> Int {
        return contacts.count
    }
    
    // MARK: - System Contacts Loading
    
    func loadSystemContacts() async {
        logger.info("🔍 Loading system contacts...")
        
        await MainActor.run {
            isLoading = true
        }
        
        let store = CNContactStore()
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactIdentifierKey,
            CNContactOrganizationNameKey,
            CNContactJobTitleKey,
            CNContactPostalAddressesKey,
            CNContactImageDataKey,
            CNContactThumbnailImageDataKey
        ] as [CNKeyDescriptor]
        
        do {
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var loadedContacts: [CNContact] = []
            
            try store.enumerateContacts(with: request) { contact, stop in
                // Загружаем все контакты для правильного определения незавершенных
                let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
                let hasPhone = !contact.phoneNumbers.isEmpty
                
                // Включаем все контакты, которые имеют хотя бы имя ИЛИ телефон ИЛИ email
                if hasName || hasPhone || !contact.emailAddresses.isEmpty {
                    loadedContacts.append(contact)
                }
            }
            
            await MainActor.run {
                self.systemContacts = loadedContacts
                self.isLoading = false
                self.logger.info("✅ Loaded \(loadedContacts.count) system contacts")
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load contacts: \(error.localizedDescription)"
                self.logger.error("❌ Failed to load system contacts: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Duplicate Detection
    
    var duplicateGroups: [[CNContact]] {
        guard !systemContacts.isEmpty else { return [] }
        
        var groups: [[CNContact]] = []
        var processedContacts = Set<String>()
        
        for contact in systemContacts {
            guard !processedContacts.contains(contact.identifier) else { continue }
            
            var duplicateGroup: [CNContact] = [contact]
            processedContacts.insert(contact.identifier)
            
            // Get normalized contact info for comparison
            let contactPhones = contact.phoneNumbers.map { normalizePhoneNumber($0.value.stringValue) }
            let contactEmails = contact.emailAddresses.map { String($0.value).lowercased() }
            let contactName = normalizeContactName(contact)
            
            for otherContact in systemContacts {
                guard contact.identifier != otherContact.identifier,
                      !processedContacts.contains(otherContact.identifier) else { continue }
                
                let otherPhones = otherContact.phoneNumbers.map { normalizePhoneNumber($0.value.stringValue) }
                let otherEmails = otherContact.emailAddresses.map { String($0.value).lowercased() }
                let otherName = normalizeContactName(otherContact)
                
                var isDuplicate = false
                
                // 1. Exact phone number match (highest priority)
                if !contactPhones.isEmpty && !otherPhones.isEmpty {
                    let hasMatchingPhone = contactPhones.contains { phone in
                        otherPhones.contains(phone) && !phone.isEmpty
                    }
                    if hasMatchingPhone {
                        isDuplicate = true
                    }
                }
                
                // 2. Email match (high priority)
                if !isDuplicate && !contactEmails.isEmpty && !otherEmails.isEmpty {
                    let hasMatchingEmail = contactEmails.contains { email in
                        otherEmails.contains(email) && !email.isEmpty
                    }
                    if hasMatchingEmail {
                        isDuplicate = true
                    }
                }
                
                // 3. Similar names with at least one matching contact method
                if !isDuplicate {
                    let namesSimilar = areNamesSimilar(contactName, otherName)
                    let hasCommonContactMethod = hasCommonPhoneOrEmail(
                        phones1: contactPhones, emails1: contactEmails,
                        phones2: otherPhones, emails2: otherEmails
                    )
                    
                    // Только считаем дубликатами если есть общий способ связи (телефон или email)
                    // Не группируем контакты только по именам, если у них нет общих контактных данных
                    if namesSimilar && hasCommonContactMethod {
                        isDuplicate = true
                    }
                }
                
                if isDuplicate {
                    duplicateGroup.append(otherContact)
                    processedContacts.insert(otherContact.identifier)
                }
            }
            
            // Only add groups with more than one contact
            if duplicateGroup.count > 1 {
                // Sort group by completeness (contacts with more info first)
                duplicateGroup.sort { contact1, contact2 in
                    let score1 = calculateContactCompleteness(contact1)
                    let score2 = calculateContactCompleteness(contact2)
                    return score1 > score2
                }
                groups.append(duplicateGroup)
            }
        }
        
        // Sort groups by size (larger groups first)
        return groups.sorted { $0.count > $1.count }
    }
    
    private func normalizePhoneNumber(_ phone: String) -> String {
        return phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    }
    
    private func normalizeContactName(_ contact: CNContact) -> String {
        let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return fullName
    }
    
    private func areNamesSimilar(_ name1: String, _ name2: String) -> Bool {
        guard !name1.isEmpty && !name2.isEmpty else { return false }
        
        // Exact match
        if name1 == name2 { return true }
        
        // Check if one name contains the other (for nicknames, etc.)
        if name1.contains(name2) || name2.contains(name1) { return true }
        
        // Levenshtein distance for similar names
        let similarity = levenshteinDistance(name1, name2)
        let maxLength = max(name1.count, name2.count)
        
        // Allow up to 20% character differences for similar names, minimum 2 chars difference
        let threshold = max(2, Int(Double(maxLength) * 0.2))
        return similarity <= threshold && maxLength > 3
    }
    
    private func hasCommonPhoneOrEmail(phones1: [String], emails1: [String], phones2: [String], emails2: [String]) -> Bool {
        // Check for any common phone numbers
        for phone1 in phones1 {
            if !phone1.isEmpty && phones2.contains(phone1) {
                return true
            }
        }
        
        // Check for any common emails
        for email1 in emails1 {
            if !email1.isEmpty && emails2.contains(email1) {
                return true
            }
        }
        
        return false
    }
    
    private func calculateContactCompleteness(_ contact: CNContact) -> Int {
        var score = 0
        
        // Basic info
        if !contact.givenName.isEmpty { score += 2 }
        if !contact.familyName.isEmpty { score += 2 }
        
        // Contact methods
        score += contact.phoneNumbers.count * 3
        score += contact.emailAddresses.count * 2
        
        // Additional info
        if !contact.organizationName.isEmpty { score += 1 }
        if !contact.jobTitle.isEmpty { score += 1 }
        score += contact.postalAddresses.count
        
        return score
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        var distances = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            distances[i][0] = i
        }
        
        for j in 0...b.count {
            distances[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    distances[i][j] = distances[i-1][j-1]
                } else {
                    distances[i][j] = min(
                        distances[i-1][j] + 1,
                        distances[i][j-1] + 1,
                        distances[i-1][j-1] + 1
                    )
                }
            }
        }
        
        return distances[a.count][b.count]
    }
    
    // MARK: - Contact Merging
    
    func mergeContacts(_ contactsToMerge: [CNContact]) async -> Bool {
        guard contactsToMerge.count >= 2 else {
            logger.error("❌ Cannot merge less than 2 contacts")
            return false
        }
        
        logger.info("🔄 Starting merge of \(contactsToMerge.count) contacts")
        
        if BackupService.shared.isAutoBackupEnabled {
            logger.info("🔄 Auto backup is enabled, creating backup before merge")
            await performAutoBackup()
        }
        
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        do {
            let primaryContact = contactsToMerge.max { contact1, contact2 in
                calculateContactCompleteness(contact1) < calculateContactCompleteness(contact2)
            }!
            
            let allKeysToFetch = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey,
                CNContactIdentifierKey,
                CNContactOrganizationNameKey,
                CNContactJobTitleKey,
                CNContactPostalAddressesKey,
                CNContactImageDataKey,
                CNContactThumbnailImageDataKey
            ] as [CNKeyDescriptor]
            
            let mutablePrimaryContact = try store.unifiedContact(
                withIdentifier: primaryContact.identifier,
                keysToFetch: allKeysToFetch
            ).mutableCopy() as! CNMutableContact
            
            mergeDataIntoContact(mutablePrimaryContact, from: contactsToMerge)
            
            saveRequest.update(mutablePrimaryContact)
            
            for contact in contactsToMerge {
                if contact.identifier != primaryContact.identifier {
                    let contactToDelete = try store.unifiedContact(
                        withIdentifier: contact.identifier,
                        keysToFetch: [CNContactIdentifierKey] as [CNKeyDescriptor]
                    ).mutableCopy() as! CNMutableContact
                    
                    saveRequest.delete(contactToDelete)
                }
            }
            
            try store.execute(saveRequest)
            
            await MainActor.run {
                logger.info("✅ Successfully merged \(contactsToMerge.count) contacts into existing contact")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                logger.error("❌ Failed to merge contacts: \(error.localizedDescription)")
                self.errorMessage = "Failed to merge contacts: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    private func mergeDataIntoContact(_ targetContact: CNMutableContact, from contacts: [CNContact]) {
        var allPhones: [CNLabeledValue<CNPhoneNumber>] = []
        var seenPhones = Set<String>()
        
        for phoneValue in targetContact.phoneNumbers {
            let normalizedPhone = normalizePhoneNumber(phoneValue.value.stringValue)
            if !normalizedPhone.isEmpty {
                seenPhones.insert(normalizedPhone)
                allPhones.append(phoneValue)
            }
        }
        
        for contact in contacts {
            if contact.identifier != targetContact.identifier {
                for phoneValue in contact.phoneNumbers {
                    let normalizedPhone = normalizePhoneNumber(phoneValue.value.stringValue)
                    if !normalizedPhone.isEmpty && !seenPhones.contains(normalizedPhone) {
                        seenPhones.insert(normalizedPhone)
                        allPhones.append(phoneValue)
                    }
                }
            }
        }
        targetContact.phoneNumbers = allPhones
        
        var allEmails: [CNLabeledValue<NSString>] = []
        var seenEmails = Set<String>()
        
        for emailValue in targetContact.emailAddresses {
            let normalizedEmail = String(emailValue.value).lowercased()
            if !normalizedEmail.isEmpty {
                seenEmails.insert(normalizedEmail)
                allEmails.append(emailValue)
            }
        }
        
        for contact in contacts {
            if contact.identifier != targetContact.identifier {
                for emailValue in contact.emailAddresses {
                    let normalizedEmail = String(emailValue.value).lowercased()
                    if !normalizedEmail.isEmpty && !seenEmails.contains(normalizedEmail) {
                        seenEmails.insert(normalizedEmail)
                        allEmails.append(emailValue)
                    }
                }
            }
        }
        targetContact.emailAddresses = allEmails
        
        for contact in contacts {
            if contact.identifier != targetContact.identifier {
                if targetContact.organizationName.isEmpty && !contact.organizationName.isEmpty {
                    targetContact.organizationName = contact.organizationName
                }
                if targetContact.jobTitle.isEmpty && !contact.jobTitle.isEmpty {
                    targetContact.jobTitle = contact.jobTitle
                }
            }
        }
        
        var allAddresses: [CNLabeledValue<CNPostalAddress>] = []
        allAddresses.append(contentsOf: targetContact.postalAddresses)
        
        for contact in contacts {
            if contact.identifier != targetContact.identifier {
                allAddresses.append(contentsOf: contact.postalAddresses)
            }
        }
        targetContact.postalAddresses = allAddresses
        
        if targetContact.imageData == nil {
            for contact in contacts {
                if contact.identifier != targetContact.identifier && contact.imageData != nil {
                    targetContact.imageData = contact.imageData
                    break
                }
            }
        }
    }
    
    func mergeContactGroup(_ group: [CNContact], selectedIds: Set<String>) async -> Bool {
        let selectedContacts = group.filter { selectedIds.contains($0.identifier) }
        
        guard selectedContacts.count >= 2 else {
            await MainActor.run {
                errorMessage = "Please select at least 2 contacts to merge"
            }
            return false
        }
        
        return await mergeContacts(selectedContacts)
    }
    
    // MARK: - Contact Deletion
    
    func deleteContacts(_ contactsToDelete: [CNContact]) async -> Bool {
        guard !contactsToDelete.isEmpty else {
            logger.error("❌ No contacts to delete")
            return false
        }
        
        logger.info("🗑️ Starting deletion of \(contactsToDelete.count) contacts")
        
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        do {
            for contact in contactsToDelete {
                let contactToDelete = try store.unifiedContact(
                    withIdentifier: contact.identifier,
                    keysToFetch: [CNContactIdentifierKey] as [CNKeyDescriptor]
                ).mutableCopy() as! CNMutableContact
                
                saveRequest.delete(contactToDelete)
            }
            
            try store.execute(saveRequest)
            
            await MainActor.run {
                logger.info("✅ Successfully deleted \(contactsToDelete.count) contacts")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                logger.error("❌ Failed to delete contacts: \(error.localizedDescription)")
                self.errorMessage = "Failed to delete contacts: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Auto Backup
    
    private func performAutoBackup() async {
        logger.info("🔄 Performing automatic backup to iCloud")
        
        let contactsManager = ContactsPersistenceManager.shared
        let contacts = contactsManager.loadContacts()
        
        guard !contacts.isEmpty else {
            logger.info("ℹ️ No contacts to backup")
            return
        }
        
        let iCloudService = iCloudBackupService()
        let success = await iCloudService.backupContacts(contacts)
        
        if success {
            logger.info("✅ Auto backup completed successfully")
        } else {
            logger.error("❌ Auto backup failed: \(iCloudService.lastError?.localizedDescription ?? "Unknown error")")
        }
    }
}
