import SwiftUI

class AICleanerSafeContactsViewModel: ObservableObject, ContactViewModelProtocol {
    @Published var contacts: [ContactData] = []
    @Published var isLoading = false
    
    private let persistenceManager = ContactsPersistenceManager.shared
    
    // MARK: - CRUD Operations
    func loadContacts() {
        isLoading = true
        
        Task(priority: .userInitiated) {
            let loadedContacts = self.persistenceManager.loadContacts()
            
            // Автоматически переключает на MainActor
            self.contacts = loadedContacts
            self.isLoading = false
        }
    }
    
    func addContact(_ contact: ContactData) {
        persistenceManager.addContact(contact)
        loadContacts()
    }
    
    func updateContact(_ contact: ContactData) {
        persistenceManager.updateContact(contact)
        loadContacts()
    }
    
    func deleteContact(_ contact: ContactData) {
        persistenceManager.deleteContact(withId: contact.id)
        loadContacts()
    }
}
