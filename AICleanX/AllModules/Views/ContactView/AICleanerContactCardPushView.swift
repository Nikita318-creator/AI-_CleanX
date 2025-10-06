import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerContactCardPushView: View {
    let contact: CNContact
    @State private var fullContact: CNContact?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading contact...")
                        .foregroundColor(.secondary)
                }
            } else if let error = loadError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text("Failed to load contact")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let fullContact = fullContact {
                AICleanerContactCardWithCustomNavView(contact: fullContact)
            } else {
                Text("Contact not found")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadFullContact()
        }
    }
    
    private func loadFullContact() async {
        do {
            let store = CNContactStore()
            var keysToFetch = [
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
            keysToFetch.append(CNContactViewController.descriptorForRequiredKeys())
            
            let loadedContact = try store.unifiedContact(
                withIdentifier: contact.identifier,
                keysToFetch: keysToFetch
            )
            
            await MainActor.run {
                self.fullContact = loadedContact
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
        }
    }
}
