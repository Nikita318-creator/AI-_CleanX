import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerAllContactsView: View {
    @ObservedObject var viewModel: AICleanerContactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedContacts: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showDeleteAlert = false
    
    @State private var selectedContactForNavigation: CNContact?

    // MARK: - Body
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let scalingFactor = geometry.size.height / 844
                
                ZStack(alignment: .top) {
                    CMColor.background.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        
                        headerView(scalingFactor: scalingFactor)
                            .padding(.bottom, 16 * scalingFactor)
                        
                        searchBar(scalingFactor: scalingFactor)
                            .padding(.horizontal, 20 * scalingFactor)
                            .padding(.bottom, isSelectionMode && !selectedContacts.isEmpty ? 8 * scalingFactor : 24 * scalingFactor)
                        
                        if isSelectionMode && !selectedContacts.isEmpty {
                            deleteButton(scalingFactor: scalingFactor)
                                .padding(.horizontal, 20 * scalingFactor)
                                .padding(.bottom, 20 * scalingFactor)
                        }
                        
                        if filteredSystemContacts.isEmpty && !searchText.isEmpty {
                            Spacer()
                            Text("No matching records for \"\(searchText)\"")
                                .font(.system(size: 18 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.secondaryText)
                            Spacer()
                        } else if filteredSystemContacts.isEmpty {
                            Spacer()
                            Text("Your contact list is empty.")
                                .font(.system(size: 18 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.secondaryText)
                            Spacer()
                        } else {
                            contactsGridView(scalingFactor: scalingFactor)
                        }
                    }
                }
            }
            .background(
                NavigationLink(
                    destination: selectedContactForNavigation.map { AICleanerContactCardPushView(contact: $0) },
                    isActive: Binding(
                        get: { selectedContactForNavigation != nil },
                        set: { isPresenting in
                            if !isPresenting { selectedContactForNavigation = nil }
                        }
                    ),
                    label: { EmptyView() }
                )
                .hidden()
            )
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .alert("Confirm Deletion", isPresented: $showDeleteAlert) {
            Button("Erase Selection", role: .destructive) {
                deleteSelectedContacts()
            }
            Button("Keep Items", role: .cancel) { }
        } message: {
            Text("Are you sure you want to permanently erase \(selectedContacts.count) chosen item\(selectedContacts.count == 1 ? "" : "s")? This action cannot be undone.")
        }
    }

    // MARK: - Views
    
    private func contactsGridView(scalingFactor: CGFloat) -> some View {
        ScrollView {
            let columns = [
                GridItem(.flexible(), spacing: 16 * scalingFactor),
                GridItem(.flexible())
            ]
            
            LazyVGrid(columns: columns, spacing: 16 * scalingFactor) {
                ForEach(filteredSystemContacts, id: \.identifier) { contact in
                    ContactSquareCardView(
                        contact: contact,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedContacts.contains(contact.identifier),
                        scalingFactor: scalingFactor,
                        onTap: {
                            if isSelectionMode {
                                toggleContactSelection(contact.identifier)
                            } else {
                                selectedContactForNavigation = contact
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20 * scalingFactor)
            .padding(.vertical, 24 * scalingFactor)
        }
    }
    
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            Button(action: {
                if isSelectionMode {
                    isSelectionMode = false
                    selectedContacts.removeAll()
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 4 * scalingFactor) {
                    Image(systemName: isSelectionMode ? "xmark" : "chevron.left")
                        .font(.system(size: 24 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                    
                    Text(isSelectionMode ? "Dismiss" : "Back")
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4 * scalingFactor) {
                Text(isSelectionMode ? "Bulk Actions" : "All Contacts")
                    .font(.system(size: 24 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                if isSelectionMode && !selectedContacts.isEmpty {
                    Text("\(selectedContacts.count) record\(selectedContacts.count == 1 ? "" : "s") selected")
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            
            Spacer()
            
            Button(action: {
                if isSelectionMode {
                    if selectedContacts.isEmpty {
                        selectedContacts = Set(filteredSystemContacts.map { $0.identifier })
                    } else {
                        selectedContacts.removeAll()
                    }
                } else {
                    isSelectionMode = true
                }
            }) {
                Text(isSelectionMode ?
                     (selectedContacts.isEmpty ? "Select All" : "Deselect All") :
                        "Edit")
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
            
            TextField("Search by name, number, or company...", text: $searchText)
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
                
                Text("Delete \(selectedContacts.count) record\(selectedContacts.count == 1 ? "" : "s")")
                    .font(.system(size: 18 * scalingFactor, weight: .heavy))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54 * scalingFactor)
            .background(CMColor.error)
            .cornerRadius(16 * scalingFactor)
        }
    }
    
    // MARK: - Contact Card View
    
    struct ContactSquareCardView: View {
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
            return "Unsaved Contact"
        }

        private var avatarText: String {
            let initials = (contact.givenName.prefix(1) + contact.familyName.prefix(1)).uppercased()
            if !initials.isEmpty { return initials }
            return "#"
        }

        var body: some View {
            Button(action: onTap) {
                GeometryReader { buttonGeometry in
                    VStack(alignment: .leading, spacing: 10 * scalingFactor) {
                        
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(CMColor.primary.opacity(0.1))
                                    .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                                
                                Text(avatarText)
                                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                                    .foregroundColor(CMColor.primary)
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
                                Image(systemName: "info.circle")
                                    .font(.system(size: 24 * scalingFactor))
                                    .foregroundColor(CMColor.secondaryText.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                        
                        Text(primaryDisplay)
                            .font(.system(size: 16 * scalingFactor, weight: .bold))
                            .foregroundColor(CMColor.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        
                        Text(contact.organizationName.isEmpty ? "Personal Record" : contact.organizationName)
                            .font(.system(size: 12 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(16 * scalingFactor)
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
            let contactsToDelete = filteredSystemContacts.filter { selectedContacts.contains($0.identifier) }
            
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
    
    private var filteredSystemContacts: [CNContact] {
        let sortedContacts = viewModel.systemContacts.sorted {
            let name1 = "\($0.givenName) \($0.familyName)"
            let name2 = "\($1.givenName) \($1.familyName)"
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
        
        if searchText.isEmpty {
            return sortedContacts
        } else {
            let searchQuery = searchText.lowercased()
            return sortedContacts.filter { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)"
                let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }.joined()
                let emails = contact.emailAddresses.map { $0.value as String }.joined()
                let company = contact.organizationName
                
                return fullName.localizedCaseInsensitiveContains(searchQuery) ||
                phoneNumbers.contains(searchQuery) ||
                emails.localizedCaseInsensitiveContains(searchQuery) ||
                company.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
}
