import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerIncompleteContactsView: View {
    @ObservedObject var viewModel: AICleanerContactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedContacts: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showDeleteAlert = false
    
    // Переименованные переменные для навигации
    @State private var contactToViewDetails: CNContact?
    @State private var showDetailSheet = false

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                CMColor.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // --- Header: Classic Back Button and Updated Texts ---
                    headerView(scalingFactor: scalingFactor)
                        .padding(.bottom, 16 * scalingFactor)
                    
                    // --- Search Bar (Updated text) ---
                    searchBar(scalingFactor: scalingFactor)
                        .padding(.horizontal, 20 * scalingFactor)
                        .padding(.bottom, isSelectionMode && !selectedContacts.isEmpty ? 8 * scalingFactor : 24 * scalingFactor)
                    
                    // --- Mass Delete Button (Updated text) ---
                    if isSelectionMode && !selectedContacts.isEmpty {
                        deleteButton(scalingFactor: scalingFactor)
                            .padding(.horizontal, 20 * scalingFactor)
                            .padding(.bottom, 20 * scalingFactor)
                    }
                    
                    // --- Content: Contacts Grid (Two Square Cells Per Row) ---
                    if filteredIncompleteContacts.isEmpty && !searchText.isEmpty {
                        Spacer()
                        Text("No results for \"\(searchText)\" in incomplete contacts.") // Updated text
                            .font(.system(size: 18 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                        Spacer()
                    } else if filteredIncompleteContacts.isEmpty {
                        Spacer()
                        Text("All contacts seem complete.") // Updated text
                            .font(.system(size: 18 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                        Spacer()
                    } else {
                        contactsGridView(scalingFactor: scalingFactor)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        // Использование .sheet для модального представления карточки контакта
        .sheet(isPresented: $showDetailSheet) {
            if let contact = contactToViewDetails {
                // ПРЕДПОЛАГАЕТСЯ, ЧТО AICleanerContactCardPushView СУЩЕСТВУЕТ В ДРУГОМ МЕСТЕ
                AICleanerContactCardPushView(contact: contact)
            }
        }
        .alert("Remove Unfinished Entries", isPresented: $showDeleteAlert) { // Updated text
            Button("Erase Selection", role: .destructive) { // Updated text
                deleteSelectedContacts()
            }
            Button("Cancel Action", role: .cancel) { } // Updated text
        } message: {
            Text("Confirm the permanent deletion of \(selectedContacts.count) incomplete record\(selectedContacts.count == 1 ? "" : "s")? This is irreversible.") // Updated text
        }
    }
    
    // MARK: - Auxiliary Views (Defined locally for compilation safety)
    
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            // CLASSIC BACK BUTTON (Chevron)
            Button(action: {
                if isSelectionMode {
                    isSelectionMode = false
                    selectedContacts.removeAll()
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 4 * scalingFactor) {
                    Image(systemName: isSelectionMode ? "xmark" : "chevron.left") // Classic iOS back arrow/Close icon
                        .font(.system(size: 24 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                    
                    Text(isSelectionMode ? "Dismiss" : "Return") // Updated text
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4 * scalingFactor) {
                Text(isSelectionMode ? "Bulk Removal" : "Incomplete Entries") // Updated text
                    .font(.system(size: 24 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                if isSelectionMode && !selectedContacts.isEmpty {
                    Text("\(selectedContacts.count) records chosen") // Updated text
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                } else {
                    Text("Found \(filteredIncompleteContacts.count) incomplete contacts") // Updated text
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            
            Spacer()
            
            Button(action: {
                if isSelectionMode {
                    if selectedContacts.isEmpty {
                        selectedContacts = Set(filteredIncompleteContacts.map { $0.identifier })
                    } else {
                        selectedContacts.removeAll()
                    }
                } else {
                    isSelectionMode = true
                }
            }) {
                Text(isSelectionMode ?
                     (selectedContacts.isEmpty ? "Select All" : "Clear All") : // Updated text
                        "Bulk Edit") // Updated text
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            }
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.top, 16 * scalingFactor)
        .padding(.bottom, 8 * scalingFactor)
    }
    
    private func searchBar(scalingFactor: CGFloat) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CMColor.secondaryText)
            
            TextField("Search name or number...", text: $searchText) // Updated text
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(CMColor.secondaryText)
                }
            }
        }
        .padding(.horizontal, 12 * scalingFactor)
        .padding(.vertical, 8 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(10 * scalingFactor)
    }
    
    private func deleteButton(scalingFactor: CGFloat) -> some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18 * scalingFactor, weight: .heavy))
                
                Text("Delete \(selectedContacts.count) record\(selectedContacts.count == 1 ? "" : "s")") // Updated text
                    .font(.system(size: 18 * scalingFactor, weight: .heavy))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54 * scalingFactor)
            .background(CMColor.error)
            .cornerRadius(16 * scalingFactor)
        }
    }
    
    private func contactsGridView(scalingFactor: CGFloat) -> some View {
        ScrollView {
            let columns = [
                GridItem(.flexible(), spacing: 16 * scalingFactor),
                GridItem(.flexible())
            ]
            
            LazyVGrid(columns: columns, spacing: 16 * scalingFactor) {
                ForEach(filteredIncompleteContacts, id: \.identifier) { contact in
                    // Используем локально определенное вью для квадратной ячейки
                    IncompleteContactSquareCardView(
                        contact: contact,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedContacts.contains(contact.identifier),
                        scalingFactor: scalingFactor,
                        onTap: {
                            if isSelectionMode {
                                toggleContactSelection(contact.identifier)
                            } else {
                                contactToViewDetails = contact
                                showDetailSheet = true
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20 * scalingFactor)
            .padding(.vertical, 24 * scalingFactor)
        }
    }
    
    // MARK: - Local Contact Card View (to display incomplete contacts)
    
    struct IncompleteContactSquareCardView: View {
        let contact: CNContact
        let isSelectionMode: Bool
        let isSelected: Bool
        let scalingFactor: CGFloat
        let onTap: () -> Void
        
        private var primaryDisplay: String {
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
            if let phone = contact.phoneNumbers.first?.value.stringValue { return phone }
            if let email = contact.emailAddresses.first?.value as? String { return email }
            return "No Name/Data" // Updated text
        }

        private var avatarText: String {
            let initials = (contact.givenName.prefix(1) + contact.familyName.prefix(1)).uppercased()
            if !initials.isEmpty { return initials }
            return "!"
        }
        
        private var missingInfo: String {
            var parts: [String] = []
            if contact.givenName.isEmpty && contact.familyName.isEmpty { parts.append("Name") }
            if contact.phoneNumbers.isEmpty { parts.append("Phone") }
            if contact.emailAddresses.isEmpty { parts.append("Email") }
            
            if parts.count == 3 { return "No info" }
            if parts.count == 1 { return "\(parts.first!) missing" }
            if parts.count == 2 { return "\(parts.joined(separator: " & ")) missing" }
            return "Incomplete"
        }

        var body: some View {
            Button(action: onTap) {
                GeometryReader { buttonGeometry in
                    VStack(alignment: .leading, spacing: 10 * scalingFactor) {
                        
                        // 1. Avatar & Selection Checkbox
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(CMColor.error.opacity(0.15)) // Highlight with error color
                                    .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                                
                                Text(avatarText)
                                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                                    .foregroundColor(CMColor.error)
                            }
                            
                            Spacer()
                            
                            if isSelectionMode {
                                ZStack {
                                    Circle()
                                        .stroke(isSelected ? CMColor.primary : CMColor.secondaryText.opacity(0.5), lineWidth: 2 * scalingFactor)
                                        .frame(width: 24 * scalingFactor, height: 24 * scalingFactor)
                                    
                                    if isSelected {
                                        Circle()
                                            .fill(CMColor.primary)
                                            .frame(width: 16 * scalingFactor, height: 16 * scalingFactor)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10 * scalingFactor, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            } else {
                                Image(systemName: "info.circle.fill") // Icon for details
                                    .font(.system(size: 24 * scalingFactor))
                                    .foregroundColor(CMColor.error)
                            }
                        }
                        
                        Spacer()
                        
                        // 2. Primary Identifier
                        Text(primaryDisplay)
                            .font(.system(size: 16 * scalingFactor, weight: .bold))
                            .foregroundColor(CMColor.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        
                        // 3. Secondary info (What's missing)
                        Text("Missing: \(missingInfo)") // Updated text
                            .font(.system(size: 12 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.error)
                            .lineLimit(1)
                    }
                    .padding(16 * scalingFactor)
                    // Ensure the card is square
                    .frame(width: buttonGeometry.size.width, height: buttonGeometry.size.width)
                    .background(
                        RoundedRectangle(cornerRadius: 16 * scalingFactor)
                            .fill(isSelected ? CMColor.primary.opacity(0.1) : CMColor.surface)
                            .shadow(color: .black.opacity(0.05), radius: 4 * scalingFactor, x: 0, y: 2 * scalingFactor)
                    )
                }
                .aspectRatio(1, contentMode: .fit)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Logic
    
    private func toggleContactSelection(_ contactId: String) {
        if selectedContacts.contains(contactId) {
            selectedContacts.remove(contactId)
        } else {
            selectedContacts.insert(contactId)
        }
    }
    
    private func deleteSelectedContacts() {
        Task {
            let contactsToDelete = filteredIncompleteContacts.filter { selectedContacts.contains($0.identifier) }
            
            let success = await viewModel.deleteContacts(contactsToDelete)
            
            await MainActor.run {
                if success {
                    selectedContacts.removeAll()
                    isSelectionMode = false
                    Task {
                        await viewModel.loadSystemContacts()
                    }
                }
            }
        }
    }
    
    private var filteredIncompleteContacts: [CNContact] {
        let incomplete = viewModel.systemContacts.filter { contact in
            // A contact is "incomplete" if it lacks a name AND a phone number AND an email.
            // OR simply lacks a Name (givenName + familyName) as a common definition of "incomplete"
            let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
            let hasPhoneOrEmail = !contact.phoneNumbers.isEmpty || !contact.emailAddresses.isEmpty
            
            // Define an incomplete contact as one lacking a name, OR lacking phone/email
            // Using the simpler definition of a contact that lacks a name OR a number OR an email.
            return !hasName || !hasPhoneOrEmail
        }.sorted {
            let name1 = "\($0.givenName) \($0.familyName)"
            let name2 = "\($1.givenName) \($1.familyName)"
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
        
        if searchText.isEmpty {
            return incomplete
        } else {
            return incomplete.filter { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)"
                let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }.joined()
                let emails = contact.emailAddresses.map { $0.value as String }.joined()
                let company = contact.organizationName
                let searchQuery = searchText.lowercased()
                
                return fullName.localizedCaseInsensitiveContains(searchQuery) ||
                phoneNumbers.contains(searchQuery) ||
                emails.localizedCaseInsensitiveContains(searchQuery) ||
                company.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
}
