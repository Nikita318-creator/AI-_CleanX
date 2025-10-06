import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerSafeContactsView: View {
    @StateObject private var viewModel = AICleanerSafeContactsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showAddContact = false
    @State private var selectedContactForEdit: ContactData?
    @State private var showEditContact = false

    @State private var showContactPicker = false
    @StateObject private var permissionManager = ContactsPermissionManager()
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @State private var showSystemContactCard = false
    @State private var selectedContactForSystemCard: ContactData?
    @State private var showDeleteFromDeviceAlert = false
    @State private var contactsToImport: [CNContact] = []
    @State private var showContextMenu = false
    @State private var selectedContactForContext: ContactData?
    @State private var showDeleteFromSafeStorageAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView(scalingFactor: scalingFactor)
                    
                    if viewModel.isLoading {
                        loadingView(scalingFactor: scalingFactor)
                    } else {
                        // Search Bar
                        searchBarView(scalingFactor: scalingFactor)
                        
                        // Contacts List
                        contactsListView(scalingFactor: scalingFactor)
                    }
                    
                    // Add Contact Button
                    addContactButton(scalingFactor: scalingFactor)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showAddContact) {
            AddContactView(viewModel: AnyContactViewModel(viewModel), contactToEdit: nil)
        }
        .fullScreenCover(isPresented: $showEditContact) {
            AddContactView(viewModel: AnyContactViewModel(viewModel), contactToEdit: selectedContactForEdit)
        }

        .sheet(isPresented: $showContactPicker) {
            AICleanerContactPickerView(isPresented: $showContactPicker) { contacts in
                contactsToImport = contacts
                showDeleteFromDeviceAlert = true
            }
        }

        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Successfully imported \(importedCount) contact\(importedCount == 1 ? "" : "s") to Safe Storage.")
        }
        .sheet(isPresented: $showSystemContactCard) {
            if let contact = selectedContactForSystemCard {
                AICleanerSafeContactCardView(contact: contact)
            }
        }
        .alert("Delete from Device", isPresented: $showDeleteFromDeviceAlert) {
            Button("Yes", role: .destructive) {
                handleImportAndDeleteFromDevice()
            }
            Button("No", role: .cancel) {
                handleImportOnly()
            }
        } message: {
            Text("Do you want to delete contacts from your device?")
        }
        .confirmationDialog("Contact Actions", isPresented: $showContextMenu) {
            if let contact = selectedContactForContext {
                Button("Call") {
                    makePhoneCall(to: contact.phoneNumber)
                }
                
                Button("Delete", role: .destructive) {
                    showDeleteFromSafeStorageAlert = true
                }
                
                Button("Cancel", role: .cancel) {
                    selectedContactForContext = nil
                }
            }
        } message: {
            if let contact = selectedContactForContext {
                Text("Actions for \(contact.fullName)")
            }
        }
        .alert("Delete Contact", isPresented: $showDeleteFromSafeStorageAlert) {
            Button("Delete", role: .destructive) {
                if let contact = selectedContactForContext {
                    viewModel.deleteContact(contact)
                    selectedContactForContext = nil
                }
            }
            Button("Cancel", role: .cancel) {
                selectedContactForContext = nil
            }
        } message: {
            if let contact = selectedContactForContext {
                Text("Are you sure you want to delete \(contact.fullName) from Safe Storage?")
            }
        }
        .onAppear {
            viewModel.loadContacts()
            permissionManager.checkAuthorizationStatus()
        }
    }
    
    // MARK: - Header View
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                    
                    Text("Back")
                        .font(.system(size: 17 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.primary)
                }
            }
            
            Spacer()
            
            Text("Safe Contacts")
                .font(.system(size: 20 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            // Balance with invisible button
            HStack(spacing: 6 * scalingFactor) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                Text("Back")
                    .font(.system(size: 17 * scalingFactor, weight: .regular))
            }
            .opacity(0)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.top, 8 * scalingFactor)
        .padding(.bottom, 20 * scalingFactor)
    }
    
    // MARK: - Search Bar View
    private func searchBarView(scalingFactor: CGFloat) -> some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(CMColor.secondaryText)
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                
                TextField("Name, phone, or email", text: $searchText)
                    .font(.system(size: 16 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.primaryText)
                
                Spacer()
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.secondaryText)
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                    }
                }
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 12 * scalingFactor)
            .background(CMColor.backgroundSecondary)
            .cornerRadius(12 * scalingFactor)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.bottom, 20 * scalingFactor)
    }
    
    // MARK: - Loading View
    private func loadingView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: CMColor.primary))
                .scaleEffect(1.2)
            
            Text("Loading contacts...")
                .font(.system(size: 16 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Contacts List View
    private func contactsListView(scalingFactor: CGFloat) -> some View {
        ScrollView {
            if filteredContacts.isEmpty {
                emptyStateView(scalingFactor: scalingFactor)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredContacts.enumerated()), id: \.element.id) { index, contact in
                        contactRow(contact: contact, scalingFactor: scalingFactor)
                            .onTapGesture {
                                selectedContactForSystemCard = contact
                                showSystemContactCard = true
                            }
                            .onLongPressGesture {
                                selectedContactForContext = contact
                                showContextMenu = true
                            }
                        
                        if index < filteredContacts.count - 1 {
                            Divider()
                                .background(CMColor.border)
                                .padding(.horizontal, 16 * scalingFactor)
                        }
                    }
                }
                .padding(.bottom, 100 * scalingFactor)
            }
        }
    }
    
    // MARK: - Contact Row
    private func contactRow(contact: ContactData, scalingFactor: CGFloat) -> some View {
        HStack(spacing: 16 * scalingFactor) {
            // Contact Initial Circle
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                
                Text(contact.initials)
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                Text(contact.fullName)
                    .font(.system(size: 17 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(contact.formattedPhoneNumber)
                    .font(.system(size: 15 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
            
            // Edit indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 16 * scalingFactor)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
    
    // MARK: - Empty State View
    private func emptyStateView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scalingFactor) {
            // Icon
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 80 * scalingFactor, height: 80 * scalingFactor)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 32 * scalingFactor, weight: .light))
                    .foregroundColor(CMColor.primary)
            }
            
            // Text
            VStack(spacing: 8 * scalingFactor) {
                Text(searchText.isEmpty ? "No contacts yet" : "No results found")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(searchText.isEmpty ? "Add your first contact to get started.\nYou can create a new one or import from your device." : "Try a different search term")
                    .font(.system(size: 16 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100 * scalingFactor)
    }
    
    // MARK: - Add Contact Buttons
    private func addContactButton(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 12 * scalingFactor) {
            Spacer()
            
            HStack(spacing: 12 * scalingFactor) {
                // Import Button
                Button(action: {
                    handleImportFromContacts()
                }) {
                    HStack(spacing: 8 * scalingFactor) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        
                        Text("Import")
                            .font(.system(size: 17 * scalingFactor, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16 * scalingFactor)
                    .background(CMColor.primary)
                    .cornerRadius(12 * scalingFactor)
                }
                
                // Add Manually Button
                Button(action: {
                    showAddContact = true
                }) {
                    HStack(spacing: 8 * scalingFactor) {
                        Image(systemName: "plus")
                            .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        
                        Text("Add manually")
                            .font(.system(size: 17 * scalingFactor, weight: .semibold))
                    }
                    .foregroundColor(CMColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16 * scalingFactor)
                    .background(CMColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12 * scalingFactor)
                            .stroke(CMColor.primary, lineWidth: 1)
                    )
                    .cornerRadius(12 * scalingFactor)
                }
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.bottom, 32 * scalingFactor)
        }
    }
    
    // MARK: - Helper Methods
    private func handleImportFromContacts() {
        if permissionManager.canAccessContacts {
            showContactPicker = true
        } else {
            Task {
                let granted = await permissionManager.requestAccess()
                if granted {
                    await MainActor.run {
                        showContactPicker = true
                    }
                }
            }
        }
    }
    
    private func handleImportedContacts(_ cnContacts: [CNContact]) {
        var importedContactsCount = 0
        
        for cnContact in cnContacts {
            let contactData = ContactImportHelper.convertToContactData(cnContact)
            
            // Check if contact already exists
            let exists = viewModel.contacts.contains { existingContact in
                existingContact.phoneNumber == contactData.phoneNumber ||
                (existingContact.firstName == contactData.firstName && 
                 existingContact.lastName == contactData.lastName)
            }
            
            if !exists {
                viewModel.addContact(contactData)
                importedContactsCount += 1
            }
        }
        
        // Show success message
        if importedContactsCount > 0 {
            importedCount = importedContactsCount
            showImportSuccess = true
        }
    }
    
    private func handleImportOnly() {
        handleImportedContacts(contactsToImport)
        contactsToImport = []
    }
    
    private func handleImportAndDeleteFromDevice() {
        // Сначала импортируем контакты в SafeStorage
        handleImportedContacts(contactsToImport)
        
        // Затем удаляем их с устройства
        deleteContactsFromDevice(contactsToImport)
        
        contactsToImport = []
    }
    
    private func deleteContactsFromDevice(_ cnContacts: [CNContact]) {
        let store = CNContactStore()
        
        Task {
            do {
                for cnContact in cnContacts {
                    // Получаем mutable версию контакта
                    let mutableContact = cnContact.mutableCopy() as! CNMutableContact
                    
                    // Создаем запрос на удаление
                    let saveRequest = CNSaveRequest()
                    saveRequest.delete(mutableContact)
                    
                    // Выполняем удаление
                    try store.execute(saveRequest)
                }
                
                await MainActor.run {
                    print("Successfully deleted \(cnContacts.count) contacts from device")
                }
            } catch {
                await MainActor.run {
                    print("Error deleting contacts from device: \(error)")
                }
            }
        }
    }
    
    private func makePhoneCall(to phoneNumber: String) {
        // Очищаем номер телефона от лишних символов
        let cleanedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if let url = URL(string: "tel://\(cleanedNumber)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                print("Cannot make phone calls on this device")
            }
        }
    }
    
    // MARK: - Computed Properties
    private var filteredContacts: [ContactData] {
        if searchText.isEmpty {
            return viewModel.contacts.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        } else {
            return viewModel.contacts.filter { contact in
                let searchQuery = searchText.lowercased()
                return contact.fullName.lowercased().contains(searchQuery) ||
                       contact.phoneNumber.lowercased().contains(searchQuery) ||
                       (contact.email?.lowercased().contains(searchQuery) ?? false)
            }.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        }
    }
}
