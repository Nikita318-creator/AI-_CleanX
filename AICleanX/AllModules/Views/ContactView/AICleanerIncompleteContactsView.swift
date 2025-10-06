import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerIncompleteContactsView: View {
    @ObservedObject var viewModel: AICleanerContactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Единый хедер, как на экране с дубликатами, но с другим заголовком
                VStack(spacing: 12) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.backward.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(CMColor.primary)
                                
                                Text("Go Back")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Эта кнопка здесь только для выравнивания, как на вашем экране с дубликатами
                            // Если в `Incomplete` нет такой кнопки, этот блок можно удалить.
                            // Я добавил ее, чтобы обеспечить полное сходство.
                            // Если она не нужна, просто удалите этот блок, это не повлияет на выравнивание
                            // так как мы используем Spacer().
                            Task {
                                // Здесь может быть код для обновления контактов
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(CMColor.primary)
                                
                                Text("Refresh")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Главный заголовок
                    Text("Incomplete Contacts")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(CMColor.primaryText)
                    
                    // Описание под заголовком
                    Text("Contacts that are missing key information.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CMColor.primaryText.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
                .background(LinearGradient(gradient: Gradient(colors: [CMColor.background, CMColor.backgroundSecondary]), startPoint: .top, endPoint: .bottom))
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CMColor.secondaryText)
                    
                    TextField("Name, number, company or email", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(CMColor.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(CMColor.surface) // Используем CMColor.surface для фона
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 16)
                .padding(.top, 20)

                if incompleteContacts.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 64))
                            .foregroundColor(CMColor.success)
                        
                        VStack(spacing: 8) {
                            Text("All Contacts are Complete")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(CMColor.primaryText)
                            
                            Text("All your contacts have complete information. Everything looks great!")
                                .font(.body)
                                .foregroundColor(CMColor.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredIncompleteContacts.enumerated()), id: \.element.identifier) { index, contact in
                                NavigationLink(destination: AICleanerContactCardPushView(contact: contact)) {
                                    AICleanerIncompleteContactRow(contact: contact)
                                        .background(CMColor.background)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if index < filteredIncompleteContacts.count - 1 {
                                    Divider()
                                        .background(CMColor.border)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
            }
            .background(CMColor.background)
        }
        .navigationBarHidden(true)
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var incompleteContacts: [CNContact] {
        return viewModel.systemContacts.filter { contact in
            let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
            let hasPhone = !contact.phoneNumbers.isEmpty
            
            return !hasName || !hasPhone
        }
    }
    
    private var filteredIncompleteContacts: [CNContact] {
        let contacts = searchText.isEmpty ? incompleteContacts : incompleteContacts.filter { contact in
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }.joined(separator: " ")
            let emails = contact.emailAddresses.map { $0.value as String }.joined(separator: " ")
            let company = contact.organizationName
            
            let searchQuery = searchText.lowercased()
            
            return fullName.lowercased().contains(searchQuery) ||
            phoneNumbers.lowercased().contains(searchQuery) ||
            emails.lowercased().contains(searchQuery) ||
            company.lowercased().contains(searchQuery)
        }
        
        return contacts.sorted {
            let name1 = "\($0.givenName) \($0.familyName)".trimmingCharacters(in: .whitespaces)
            let name2 = "\($1.givenName) \($1.familyName)".trimmingCharacters(in: .whitespaces)
            
            if name1.isEmpty && !name2.isEmpty { return false }
            if !name1.isEmpty && name2.isEmpty { return true }
            if name1.isEmpty && name2.isEmpty { return false }
            
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
}
