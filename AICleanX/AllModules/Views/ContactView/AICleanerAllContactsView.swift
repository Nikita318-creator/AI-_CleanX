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
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let scalingFactor = geometry.size.height / 844
                
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            if isSelectionMode {
                                isSelectionMode = false
                                selectedContacts.removeAll()
                            } else {
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 6 * scalingFactor) {
                                Image(systemName: "arrow.left.circle.fill")
                                    .font(.system(size: 20 * scalingFactor, weight: .bold))
                                    .foregroundColor(CMColor.primary)
                                
                                Text(isSelectionMode ? "Close" : "Go Back")
                                    .font(.system(size: 18 * scalingFactor, weight: .heavy))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4 * scalingFactor) {
                            Text(isSelectionMode ? "Mass Edit" : "My Contacts")
                                .font(.system(size: 24 * scalingFactor, weight: .bold))
                                .foregroundColor(CMColor.primaryText)
                            
                            if isSelectionMode && !selectedContacts.isEmpty {
                                Text("\(selectedContacts.count) items selected")
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
                                     "Manage")
                            .font(.system(size: 18 * scalingFactor, weight: .bold))
                            .foregroundColor(CMColor.primary)
                        }
                    }
                    .padding(.horizontal, 20 * scalingFactor)
                    .padding(.top, 16 * scalingFactor)
                    .padding(.bottom, 24 * scalingFactor)
                    .background(CMColor.background.opacity(0.9))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .foregroundColor(CMColor.secondaryText)
                                .font(.system(size: 20 * scalingFactor, weight: .medium))
                            
                            TextField("Find contact...", text: $searchText)
                                .font(.system(size: 18 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.primaryText)
                            
                            Spacer()
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "x.circle.fill")
                                        .foregroundColor(CMColor.secondaryText)
                                        .font(.system(size: 20 * scalingFactor))
                                }
                            }
                        }
                        .padding(.horizontal, 20 * scalingFactor)
                        .padding(.vertical, 16 * scalingFactor)
                        .background(CMColor.backgroundSecondary)
                        .cornerRadius(16 * scalingFactor)
                    }
                    .padding(.horizontal, 20 * scalingFactor)
                    .padding(.bottom, 24 * scalingFactor)
                    .padding(.top, 20)

                    if isSelectionMode && !selectedContacts.isEmpty {
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 18 * scalingFactor, weight: .heavy))
                                
                                Text("Remove \(selectedContacts.count) selected contact\(selectedContacts.count == 1 ? "" : "s")")
                                    .font(.system(size: 18 * scalingFactor, weight: .heavy))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54 * scalingFactor)
                            .background(CMColor.error)
                            .cornerRadius(16 * scalingFactor)
                        }
                        .padding(.horizontal, 20 * scalingFactor)
                        .padding(.bottom, 20 * scalingFactor)
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(sortedSectionKeys, id: \.self) { sectionKey in
                                Section {
                                    if let contactsInSection = groupedContacts[sectionKey] {
                                        ForEach(Array(contactsInSection.enumerated()), id: \.element.identifier) { index, contact in
                                            if isSelectionMode {
                                                HStack(spacing: 20 * scalingFactor) {
                                                    VStack(alignment: .leading, spacing: 6 * scalingFactor) {
                                                        Text(contact.givenName + " " + contact.familyName)
                                                            .font(.system(size: 18 * scalingFactor, weight: .bold))
                                                            .foregroundColor(CMColor.primaryText)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: selectedContacts.contains(contact.identifier) ? "square.fill" : "square")
                                                        .font(.system(size: 28 * scalingFactor))
                                                        .foregroundColor(selectedContacts.contains(contact.identifier) ? CMColor.primary : CMColor.secondaryText)
                                                        .transition(.opacity)
                                                }
                                                .padding(.horizontal, 20 * scalingFactor)
                                                .padding(.vertical, 16 * scalingFactor)
                                                .contentShape(Rectangle())
                                                .background(CMColor.background.opacity(0.8))
                                                .onTapGesture {
                                                    toggleContactSelection(contact.identifier)
                                                }
                                            } else {
                                                NavigationLink(
                                                    destination: AICleanerContactCardPushView(contact: contact),
                                                    label: {
                                                        HStack(spacing: 20 * scalingFactor) {
                                                            Image(systemName: "person.crop.circle")
                                                                .resizable()
                                                                .scaledToFit()
                                                                .frame(width: 54 * scalingFactor, height: 54 * scalingFactor)
                                                                .foregroundColor(CMColor.primary)
                                                                .clipShape(Circle())
                                                            
                                                            VStack(alignment: .leading, spacing: 6 * scalingFactor) {
                                                                Text(contact.givenName + " " + contact.familyName)
                                                                    .font(.system(size: 18 * scalingFactor, weight: .bold))
                                                                    .foregroundColor(CMColor.primaryText)
                                                            }
                                                            
                                                            Spacer()
                                                            
                                                            Image(systemName: "arrow.right.circle")
                                                                .font(.system(size: 16 * scalingFactor, weight: .heavy))
                                                                .foregroundColor(CMColor.secondaryText)
                                                        }
                                                        .padding(.horizontal, 20 * scalingFactor)
                                                        .padding(.vertical, 16 * scalingFactor)
                                                    }
                                                )
                                                .buttonStyle(PlainButtonStyle())
                                                .background(CMColor.backgroundSecondary)
                                            }
                                            
                                            if index < contactsInSection.count - 1 {
                                                Divider()
                                                    .background(CMColor.border)
                                                    .padding(.horizontal, 20 * scalingFactor)
                                            }
                                        }
                                    }
                                } header: {
                                    HStack {
                                        Text(sectionKey)
                                            .font(.system(size: 18 * scalingFactor, weight: .heavy))
                                            .foregroundColor(CMColor.secondaryText)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20 * scalingFactor)
                                    .padding(.vertical, 10 * scalingFactor)
                                    .background(CMColor.background)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            UINavigationBar.appearance().backIndicatorImage = UIImage(systemName: "arrow.left.circle")
            UINavigationBar.appearance().backIndicatorTransitionMaskImage = UIImage(systemName: "arrow.left.circle")
            UINavigationBar.appearance().layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        }
        .alert("Confirm Action", isPresented: $showDeleteAlert) {
            Button("Delete All", role: .destructive) {
                deleteSelectedContacts()
            }
            Button("Keep", role: .cancel) { }
        } message: {
            Text("Are you absolutely sure you want to permanently delete \(selectedContacts.count) contact\(selectedContacts.count == 1 ? "" : "s")? This action cannot be undone.")
        }
    }
    
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
        if searchText.isEmpty {
            return viewModel.systemContacts.sorted {
                let name1 = "\($0.givenName) \($0.familyName)"
                let name2 = "\($1.givenName) \($1.familyName)"
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        } else {
            return viewModel.systemContacts.filter { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)"
                let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }.joined()
                return fullName.localizedCaseInsensitiveContains(searchText) ||
                phoneNumbers.contains(searchText)
            }.sorted {
                let name1 = "\($0.givenName) \($0.familyName)"
                let name2 = "\($1.givenName) \($1.familyName)"
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
    }
    
    private var groupedContacts: [String: [CNContact]] {
        Dictionary(grouping: filteredSystemContacts) { contact in
            let firstName = contact.givenName.isEmpty ? contact.familyName : contact.givenName
            let firstLetter = String(firstName.prefix(1)).uppercased()
            return firstLetter.isEmpty ? "#" : firstLetter
        }
    }
    
    private var sortedSectionKeys: [String] {
        groupedContacts.keys.sorted { key1, key2 in
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
    }
}
