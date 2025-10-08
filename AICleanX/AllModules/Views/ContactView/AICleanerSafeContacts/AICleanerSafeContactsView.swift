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
                        
                        // Stats Card
                        if !viewModel.contacts.isEmpty {
                            statsCard(scalingFactor: scalingFactor)
                        }
                        
                        // Contacts List
                        contactsListView(scalingFactor: scalingFactor)
                    }
                }
                
                // Floating Action Buttons
                VStack {
                    Spacer()
                    floatingActionButtons(scalingFactor: scalingFactor)
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
        .alert("Contacts Secured", isPresented: $showImportSuccess) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("\(importedCount) contact\(importedCount == 1 ? "" : "s") transferred to secure vault.")
        }
        .sheet(isPresented: $showSystemContactCard) {
            if let contact = selectedContactForSystemCard {
                AICleanerSafeContactCardView(contact: contact)
            }
        }
        .alert("Remove from Device?", isPresented: $showDeleteFromDeviceAlert) {
            Button("Remove & Secure", role: .destructive) {
                handleImportAndDeleteFromDevice()
            }
            Button("Keep Both", role: .cancel) {
                handleImportOnly()
            }
        } message: {
            Text("Would you like to remove these contacts from your device after securing them?")
        }
        .confirmationDialog("Quick Actions", isPresented: $showContextMenu) {
            if let contact = selectedContactForContext {
                Button("Call Contact") {
                    makePhoneCall(to: contact.phoneNumber)
                }
                
                Button("Remove from Vault", role: .destructive) {
                    showDeleteFromSafeStorageAlert = true
                }
                
                Button("Cancel", role: .cancel) {
                    selectedContactForContext = nil
                }
            }
        } message: {
            if let contact = selectedContactForContext {
                Text("\(contact.fullName)")
            }
        }
        .alert("Remove Contact?", isPresented: $showDeleteFromSafeStorageAlert) {
            Button("Remove", role: .destructive) {
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
                Text("This will permanently remove \(contact.fullName) from your secure vault.")
            }
        }
        .onAppear {
            viewModel.loadContacts()
            permissionManager.checkAuthorizationStatus()
        }
    }
    
    // MARK: - Header View
    private func headerView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4 * scalingFactor) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18 * scalingFactor, weight: .semibold))
                            .foregroundColor(CMColor.accent)
                    }
                    .frame(width: 44 * scalingFactor, height: 44 * scalingFactor)
                }
                
                Spacer()
                
                VStack(spacing: 2 * scalingFactor) {
                    Text("Protected Vault")
                        .font(.system(size: 18 * scalingFactor, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    
                    HStack(spacing: 4 * scalingFactor) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10 * scalingFactor))
                            .foregroundColor(CMColor.success)
                        
                        Text("Encrypted")
                            .font(.system(size: 11 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
                
                Spacer()
                
                // Balance
                Color.clear
                    .frame(width: 44 * scalingFactor, height: 44 * scalingFactor)
            }
            .padding(.horizontal, 20 * scalingFactor)
            .padding(.top, 12 * scalingFactor)
            .padding(.bottom, 16 * scalingFactor)
        }
        .background(CMColor.background)
    }
    
    // MARK: - Search Bar View
    private func searchBarView(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 10 * scalingFactor) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CMColor.iconSecondary)
                .font(.system(size: 15 * scalingFactor, weight: .semibold))
            
            TextField("Find by name or number...", text: $searchText)
                .font(.system(size: 15 * scalingFactor, weight: .regular))
                .foregroundColor(CMColor.primaryText)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(CMColor.iconSecondary)
                        .font(.system(size: 16 * scalingFactor, weight: .regular))
                }
            }
        }
        .padding(.horizontal, 18 * scalingFactor)
        .padding(.vertical, 14 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(14 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 14 * scalingFactor)
                .stroke(CMColor.border, lineWidth: 1)
        )
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.bottom, 16 * scalingFactor)
    }
    
    // MARK: - Stats Card
    private func statsCard(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 16 * scalingFactor) {
            HStack(spacing: 10 * scalingFactor) {
                ZStack {
                    Circle()
                        .fill(CMColor.accent.opacity(0.15))
                        .frame(width: 36 * scalingFactor, height: 36 * scalingFactor)
                    
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.accent)
                }
                
                VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                    Text("\(viewModel.contacts.count)")
                        .font(.system(size: 22 * scalingFactor, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text("Protected")
                        .font(.system(size: 12 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            
            Spacer()
            
            HStack(spacing: 6 * scalingFactor) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 13 * scalingFactor))
                    .foregroundColor(CMColor.success)
                
                Text("All contacts secured")
                    .font(.system(size: 13 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
            }
        }
        .padding(.horizontal, 18 * scalingFactor)
        .padding(.vertical, 16 * scalingFactor)
        .background(
            LinearGradient(
                colors: [CMColor.surface, CMColor.backgroundSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 16 * scalingFactor)
                .stroke(CMColor.border, lineWidth: 1)
        )
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.bottom, 20 * scalingFactor)
    }
    
    // MARK: - Loading View
    private func loadingView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 20 * scalingFactor) {
            ZStack {
                Circle()
                    .stroke(CMColor.border, lineWidth: 3)
                    .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: CMColor.accent))
                    .scaleEffect(1.3)
            }
            
            Text("Loading secured contacts...")
                .font(.system(size: 15 * scalingFactor, weight: .medium))
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
                LazyVStack(spacing: 10 * scalingFactor) {
                    ForEach(Array(filteredContacts.enumerated()), id: \.element.id) { index, contact in
                        contactCard(contact: contact, scalingFactor: scalingFactor)
                            .onTapGesture {
                                selectedContactForSystemCard = contact
                                showSystemContactCard = true
                            }
                            .onLongPressGesture {
                                selectedContactForContext = contact
                                showContextMenu = true
                            }
                    }
                }
                .padding(.horizontal, 20 * scalingFactor)
                .padding(.bottom, 120 * scalingFactor)
            }
        }
    }
    
    // MARK: - Contact Card
    private func contactCard(contact: ContactData, scalingFactor: CGFloat) -> some View {
        HStack(spacing: 14 * scalingFactor) {
            // Avatar with gradient border
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CMColor.accent.opacity(0.2), CMColor.secondary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56 * scalingFactor, height: 56 * scalingFactor)
                
                Text(contact.initials)
                    .font(.system(size: 20 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.accent)
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 5 * scalingFactor) {
                Text(contact.fullName)
                    .font(.system(size: 16 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11 * scalingFactor))
                        .foregroundColor(CMColor.iconSecondary)
                    
                    Text(contact.formattedPhoneNumber)
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action indicator
            Image(systemName: "ellipsis")
                .font(.system(size: 16 * scalingFactor, weight: .bold))
                .foregroundColor(CMColor.iconSecondary)
                .rotationEffect(.degrees(90))
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 14 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(14 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 14 * scalingFactor)
                .stroke(CMColor.border, lineWidth: 1)
        )
    }
    
    // MARK: - Empty State View
    private func emptyStateView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 28 * scalingFactor) {
            // Icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CMColor.accent.opacity(0.1), CMColor.secondary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100 * scalingFactor, height: 100 * scalingFactor)
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 40 * scalingFactor, weight: .light))
                    .foregroundColor(CMColor.accent)
            }
            
            // Text
            VStack(spacing: 10 * scalingFactor) {
                Text(searchText.isEmpty ? "Vault is Empty" : "Nothing Found")
                    .font(.system(size: 22 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(searchText.isEmpty ? "Start protecting your contacts by adding them\nto your secure vault below." : "Try adjusting your search criteria")
                    .font(.system(size: 15 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4 * scalingFactor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80 * scalingFactor)
    }
    
    // MARK: - Floating Action Buttons
    private func floatingActionButtons(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 14 * scalingFactor) {
            // Import Button
            Button(action: {
                handleImportFromContacts()
            }) {
                HStack(spacing: 10 * scalingFactor) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    
                    Text("Transfer from Device")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16 * scalingFactor)
                .background(
                    LinearGradient(
                        colors: [CMColor.accent, CMColor.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14 * scalingFactor)
                .shadow(color: CMColor.accent.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            
            // Add Manually Button
            Button(action: {
                showAddContact = true
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.accent)
                }
                .frame(width: 52 * scalingFactor, height: 52 * scalingFactor)
                .background(CMColor.surface)
                .cornerRadius(14 * scalingFactor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14 * scalingFactor)
                        .stroke(CMColor.accent, lineWidth: 1.5)
                )
            }
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.bottom, 36 * scalingFactor)
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
        handleImportedContacts(contactsToImport)
        deleteContactsFromDevice(contactsToImport)
        contactsToImport = []
    }
    
    private func deleteContactsFromDevice(_ cnContacts: [CNContact]) {
        let store = CNContactStore()
        
        Task {
            do {
                for cnContact in cnContacts {
                    let mutableContact = cnContact.mutableCopy() as! CNMutableContact
                    let saveRequest = CNSaveRequest()
                    saveRequest.delete(mutableContact)
                    try store.execute(saveRequest)
                }
                
                await MainActor.run {
                    print("Successfully removed \(cnContacts.count) contacts from device")
                }
            } catch {
                await MainActor.run {
                    print("Error removing contacts from device: \(error)")
                }
            }
        }
    }
    
    private func makePhoneCall(to phoneNumber: String) {
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
