import SwiftUI
import Contacts
import ContactsUI

struct AICleanerSafeContactCardView: UIViewControllerRepresentable {
    let contact: ContactData
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UINavigationController {
        // Создаем CNContact из ContactData
        let cnContact = CNMutableContact()
        cnContact.givenName = contact.firstName
        cnContact.familyName = contact.lastName
        
        // Добавляем номер телефона
        if !contact.phoneNumber.isEmpty {
            let phoneNumber = CNPhoneNumber(stringValue: contact.phoneNumber)
            let phoneNumberValue = CNLabeledValue(label: CNLabelPhoneNumberMain, value: phoneNumber)
            cnContact.phoneNumbers = [phoneNumberValue]
        }
        
        // Добавляем email
        if let email = contact.email, !email.isEmpty {
            let emailValue = CNLabeledValue(label: CNLabelHome, value: email as NSString)
            cnContact.emailAddresses = [emailValue]
        }
        
        // Добавляем заметки (если есть)
        if let notes = contact.notes, !notes.isEmpty {
            cnContact.note = notes
        }
        
        // Создаем контроллер
        let contactViewController = CNContactViewController(for: cnContact)
        contactViewController.allowsEditing = false
        contactViewController.allowsActions = true
        
        // Добавляем кнопку закрытия
        contactViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(Coordinator.dismissController)
        )
        
        let navigationController = UINavigationController(rootViewController: contactViewController)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Обновления не требуются
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: AICleanerSafeContactCardView
        
        init(_ parent: AICleanerSafeContactCardView) {
            self.parent = parent
        }
        
        @objc func dismissController() {
            parent.dismiss()
        }
    }
}

