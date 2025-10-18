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
    
    @Published var isPerformingMerge = false // Для блокировки кнопки во время слияния
    @Published var mergeSuccessMessage: String? // Сообщение для алерта об успешном слиянии
    @Published var showMergeSuccess = false // Флаг для отображения алерта об успехе слияния
    @Published var duplicateGroups: [[CNContact]] = [] // Теперь это должно быть @Published свойство
    @Published var incompleteContactCount: Int = 0
    @Published var totalDuplicateContactCount: Int = 0 // Добавлено для Header View
    
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
        self.contacts = persistenceManager.loadContacts()
        isLoading = false
    }
    
    func addContact(_ contactData: ContactData) {
        persistenceManager.addContact(contactData)
        self.contacts.append(contactData)
    }
    
    func updateContact(_ contactData: ContactData) {
        persistenceManager.updateContact(contactData)
        
        if let index = contacts.firstIndex(where: { $0.id == contactData.id }) {
            contacts[index] = contactData
        }
    }
    
    func deleteContact(_ contactData: ContactData) {
        persistenceManager.deleteContact(withId: contactData.id)
        contacts.removeAll { $0.id == contactData.id }
    }
    
    func deleteContacts(_ contactsToDelete: [ContactData]) {
        for contact in contactsToDelete {
            deleteContact(contact)
        }
    }
    
    private func filterContacts() {
        objectWillChange.send()
    }
    
    // MARK: - Helper Methods
    
    private func validateContactData(_ contactData: ContactData) -> Bool {
        return !contactData.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
               !contactData.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Contact Import Functions
    
    func importContacts(_ cnContacts: [CNContact]) {
        var importedCount = 0
        var skippedCount = 0
        var validCNContacts: [CNContact] = []
        
        for cnContact in cnContacts {
            let contactData = ContactImportHelper.convertToContactData(cnContact)
            
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
            }
        }
        
        importedContactsCount = importedCount
        importedCNContacts = validCNContacts
        
        if importedCount > 0 {
            showDeleteFromPhoneAlert = true
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
        _ = await ContactImportHelper.deleteContactsFromPhone(self.importedCNContacts)
        
        await MainActor.run {
            self.importedCNContacts.removeAll()
            self.showDeleteFromPhoneAlert = false
        }
    }
    
    func cancelDeleteFromPhone() {
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
    
    // Внутри AICleanerContactsViewModel:
    func loadSystemContacts() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil // Очищаем ошибку
        }
        
        do {
            // 1. Загрузка контактов (Уже на фоне через Task.detached)
            let loadedContacts = try await Task.detached { () -> [CNContact] in
                let store = CNContactStore()
                let keysToFetch = [
                    CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey,
                    CNContactEmailAddressesKey, CNContactIdentifierKey, CNContactOrganizationNameKey,
                    CNContactJobTitleKey, CNContactPostalAddressesKey, CNContactImageDataKey,
                    CNContactThumbnailImageDataKey
                ] as [CNKeyDescriptor]
                
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var contacts: [CNContact] = []
                
                try store.enumerateContacts(with: request) { contact, stop in
                    if !contact.givenName.isEmpty || !contact.familyName.isEmpty || !contact.phoneNumbers.isEmpty || !contact.emailAddresses.isEmpty {
                        contacts.append(contact)
                    }
                }
                return contacts
            }.value

            // 2. Анализ контактов (Поиск дубликатов и неполных - на фоне)
            let analysisResults = await Task.detached { [self] () -> (groups: [[CNContact]], incompleteCount: Int, totalDuplicates: Int) in
                
                // 🚨 ИСПРАВЛЕНИЕ: Вызываем findDuplicateGroups (она Sendable, так как является методом)
                let groups = await self.findDuplicateGroups(contacts: loadedContacts)
                
                // 💡 ИСПРАВЛЕНИЕ: Логика isIncompleteContact переносится сюда
                func checkIsIncompleteContact(_ contact: CNContact) -> Bool {
                    let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
                    let hasPhone = !contact.phoneNumbers.isEmpty
                    return !hasName || !hasPhone
                }
                
                let incompleteCount = loadedContacts.filter { checkIsIncompleteContact($0) }.count
                let totalDuplicates = groups.flatMap { $0 }.count
                
                return (groups, incompleteCount, totalDuplicates)
            }.value
            
            // 3. Обновление UI в MainActor
            await MainActor.run {
                self.systemContacts = loadedContacts
                self.duplicateGroups = analysisResults.groups
                self.incompleteContactCount = analysisResults.incompleteCount
                self.totalDuplicateContactCount = analysisResults.totalDuplicates
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            }
        }
    }
    
    // Внутри AICleanerContactsViewModel:
    private func isIncompleteContact(_ contact: CNContact) -> Bool {
        let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
        let hasPhone = !contact.phoneNumbers.isEmpty
        return !hasName || !hasPhone
    }
    
    // Внутри AICleanerContactsViewModel:
    func findDuplicateGroups(contacts: [CNContact]) -> [[CNContact]] {
        guard !contacts.isEmpty else { return [] }
            
        var groups: [[CNContact]] = []
        var processedContacts = Set<String>()
            
        for contact in contacts {
            guard !processedContacts.contains(contact.identifier) else { continue }
                
            var duplicateGroup: [CNContact] = [contact]
            processedContacts.insert(contact.identifier)
                
            let contactPhones = contact.phoneNumbers.map { normalizePhoneNumber($0.value.stringValue) }
            let contactEmails = contact.emailAddresses.map { String($0.value).lowercased() }
            let contactName = normalizeContactName(contact)
                
            for otherContact in contacts {
                guard contact.identifier != otherContact.identifier,
                      !processedContacts.contains(otherContact.identifier) else { continue }
                    
                let otherPhones = otherContact.phoneNumbers.map { normalizePhoneNumber($0.value.stringValue) }
                let otherEmails = otherContact.emailAddresses.map { String($0.value).lowercased() }
                let otherName = normalizeContactName(otherContact)
                    
                var isDuplicate = false
                    
                // 1. Совпадение телефонов
                if !contactPhones.isEmpty && !otherPhones.isEmpty {
                    let hasMatchingPhone = contactPhones.contains { phone in
                        otherPhones.contains(phone) && !phone.isEmpty
                    }
                    if hasMatchingPhone { isDuplicate = true }
                }
                    
                // 2. Совпадение почты (если нет телефона)
                if !isDuplicate && !contactEmails.isEmpty && !otherEmails.isEmpty {
                    let hasMatchingEmail = contactEmails.contains { email in
                        otherEmails.contains(email) && !email.isEmpty
                    }
                    if hasMatchingEmail { isDuplicate = true }
                }
                    
                // 3. Совпадение по имени + общая контактная информация
                if !isDuplicate {
                    let namesSimilar = areNamesSimilar(contactName, otherName)
                    let hasCommonContactMethod = hasCommonPhoneOrEmail(
                        phones1: contactPhones, emails1: contactEmails,
                        phones2: otherPhones, emails2: otherEmails
                    )
                        
                    if namesSimilar && hasCommonContactMethod {
                        isDuplicate = true
                    }
                }
                    
                if isDuplicate {
                    duplicateGroup.append(otherContact)
                    processedContacts.insert(otherContact.identifier)
                }
            }
                
            if duplicateGroup.count > 1 {
                duplicateGroup.sort { contact1, contact2 in
                    let score1 = calculateContactCompleteness(contact1)
                    let score2 = calculateContactCompleteness(contact2)
                    return score1 > score2
                }
                groups.append(duplicateGroup)
            }
        }
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
        if name1 == name2 { return true }
        if name1.contains(name2) || name2.contains(name1) { return true }
        let similarity = levenshteinDistance(name1, name2)
        let maxLength = max(name1.count, name2.count)
        let threshold = max(2, Int(Double(maxLength) * 0.2))
        return similarity <= threshold && maxLength > 3
    }
    
    private func hasCommonPhoneOrEmail(phones1: [String], emails1: [String], phones2: [String], emails2: [String]) -> Bool {
        for phone1 in phones1 {
            if !phone1.isEmpty && phones2.contains(phone1) {
                return true
            }
        }
        
        for email1 in emails1 {
            if !email1.isEmpty && emails2.contains(email1) {
                return true
            }
        }
        
        return false
    }
    
    func calculateContactCompleteness(_ contact: CNContact) -> Int {
        var score = 0
        if !contact.givenName.isEmpty { score += 2 }
        if !contact.familyName.isEmpty { score += 2 }
        score += contact.phoneNumbers.count * 3
        score += contact.emailAddresses.count * 2
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
        
    func mergeSelectedContacts(selectedIds: Set<String>) async -> Bool {
        let contactsToMerge = self.systemContacts.filter { selectedIds.contains($0.identifier) }

        guard contactsToMerge.count >= 2 else {
            await MainActor.run {
                self.errorMessage = "Please select at least 2 contacts to merge."
            }
            return false
        }

        return await self.mergeContacts(contactsToMerge)
    }


    func mergeContactGroup(_ group: [CNContact], masterContact: CNContact) async -> Bool {
        let contactsToMerge = group.filter { $0.identifier != masterContact.identifier }
        var finalMergeList = [CNContact]()
        finalMergeList.append(masterContact)
        finalMergeList.append(contentsOf: contactsToMerge)
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        do {
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
            
            let mutableMasterContact = try store.unifiedContact(
                withIdentifier: masterContact.identifier,
                keysToFetch: keysToFetch
            ).mutableCopy() as! CNMutableContact
            
            mergeDataIntoContact(mutableMasterContact, from: contactsToMerge)
            saveRequest.update(mutableMasterContact)
            
            for contact in contactsToMerge {
                 let contactToDelete = try store.unifiedContact(
                     withIdentifier: contact.identifier,
                     keysToFetch: keysToFetch
                 ).mutableCopy() as! CNMutableContact
                 saveRequest.delete(contactToDelete)
            }
            
            try store.execute(saveRequest)
            return true

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to perform detailed merge: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func mergeContacts(_ contactsToMerge: [CNContact]) async -> Bool {
        guard contactsToMerge.count >= 2 else {
            return false
        }
        
        if BackupService.shared.isAutoBackupEnabled {
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
                        keysToFetch: allKeysToFetch
                    ).mutableCopy() as! CNMutableContact
                    
                    saveRequest.delete(contactToDelete)
                }
            }
            
            try store.execute(saveRequest)
            return true
        } catch {
            await MainActor.run {
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
        
    func deleteContacts(_ contactsToDelete: [CNContact]) async -> Bool {
        guard !contactsToDelete.isEmpty else {
            return false
        }
                
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
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
            for contact in contactsToDelete {
                let contactToDelete = try store.unifiedContact(
                    withIdentifier: contact.identifier,
                    keysToFetch: keysToFetch
                ).mutableCopy() as! CNMutableContact
                
                saveRequest.delete(contactToDelete)
            }
            
            try store.execute(saveRequest)
            
            return true
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete contacts: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    private func performAutoBackup() async {
        let contactsManager = ContactsPersistenceManager.shared
        let contacts = contactsManager.loadContacts()
        
        guard !contacts.isEmpty else {
            logger.info("ℹ️ No contacts to backup")
            return
        }
        
        let iCloudService = iCloudBackupService()
        _ = await iCloudService.backupContacts(contacts)
    }
}
