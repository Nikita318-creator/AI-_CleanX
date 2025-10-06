import SwiftUI
import ContactsUI
import Contacts

struct AICleanerContactPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onContactsSelected: ([CNContact]) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: AICleanerContactPickerView
        
        init(_ parent: AICleanerContactPickerView) {
            self.parent = parent
        }
        
        // Called when user selects contacts
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onContactsSelected(contacts)
            parent.isPresented = false
        }
        
        // Called when user selects a single contact
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactsSelected([contact])
            parent.isPresented = false
        }
        
        // Called when user cancels
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Contact Import Helper
struct ContactImportHelper {
    static func convertToContactData(_ cnContact: CNContact) -> ContactData {
        let firstName = cnContact.givenName
        let lastName = cnContact.familyName
        
        // Get the first phone number
        let phoneNumber = cnContact.phoneNumbers.first?.value.stringValue ?? ""
        
        return ContactData(
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            email: nil,
            notes: "Imported from system contacts"
        )
    }
    
    static func deleteContactsFromPhone(_ contacts: [CNContact]) async -> Bool {
        let store = CNContactStore()
        
        do {
            let saveRequest = CNSaveRequest()
            
            for contact in contacts {
                // Get the mutable contact for deletion
                let keysToFetch = [CNContactIdentifierKey] as [CNKeyDescriptor]
                if let mutableContact = try? store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keysToFetch).mutableCopy() as? CNMutableContact {
                    saveRequest.delete(mutableContact)
                }
            }
            
            try store.execute(saveRequest)
            return true
        } catch {
            print("❌ Error deleting contacts from phone: \(error)")
            return false
        }
    }
    
    static func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let digits = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Format based on length
        if digits.count == 11 && digits.hasPrefix("7") {
            // Russian format: +7 (XXX) XXX-XX-XX
            let formatted = "+7 (\(digits.dropFirst().prefix(3))) \(digits.dropFirst(4).prefix(3))-\(digits.dropFirst(7).prefix(2))-\(digits.dropFirst(9))"
            return formatted
        } else if digits.count == 10 {
            // US format: (XXX) XXX-XXXX
            let formatted = "(\(digits.prefix(3))) \(digits.dropFirst(3).prefix(3))-\(digits.dropFirst(6))"
            return formatted
        } else {
            // Return original if can't format
            return phoneNumber
        }
    }
}

// MARK: - Contacts Permission Manager
class ContactsPermissionManager: ObservableObject {
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published var hasRequestedPermissionBefore = false
    
    private let hasRequestedKey = "HasRequestedContactsPermission"
    
    init() {
        checkAuthorizationStatus()
        hasRequestedPermissionBefore = UserDefaults.standard.bool(forKey: hasRequestedKey)
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestAccess() async -> Bool {
        let store = CNContactStore()
        
        // Mark that we've requested permission
        await MainActor.run {
            hasRequestedPermissionBefore = true
            UserDefaults.standard.set(true, forKey: hasRequestedKey)
        }
        
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run {
                checkAuthorizationStatus()
            }
            return granted
        } catch {
            await MainActor.run {
                checkAuthorizationStatus()
            }
            return false
        }
    }
    
    func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
    
    var canAccessContacts: Bool {
        authorizationStatus == .authorized
    }
    
    var needsPermission: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .denied
    }
    
    var shouldRedirectToSettings: Bool {
        // Redirect if user previously denied and has requested before
        return hasRequestedPermissionBefore && authorizationStatus == .denied
    }
    
    var permissionStatusMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Доступ к контактам не настроен"
        case .denied:
            return hasRequestedPermissionBefore ? 
                "Доступ к контактам запрещен. Перейдите в Настройки для изменения разрешений." :
                "Доступ к контактам запрещен"
        case .restricted:
            return "Доступ к контактам ограничен"
        case .authorized:
            return "Доступ к контактам разрешен"
        case .limited:
            return "Доступ к контактам ограничен"
        @unknown default:
            return "Неизвестный статус доступа к контактам"
        }
    }
}
