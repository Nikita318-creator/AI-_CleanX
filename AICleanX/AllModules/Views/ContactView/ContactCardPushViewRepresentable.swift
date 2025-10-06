import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct ContactCardPushViewRepresentable: UIViewControllerRepresentable {
    let contact: CNContact
    @Binding var isEditing: Bool
    
    func makeUIViewController(context: Context) -> CNContactViewController {
        let contactViewController = CNContactViewController(for: contact)
        contactViewController.allowsEditing = true
        contactViewController.allowsActions = true
        
        // Hide the default navigation bar since we have custom one
        contactViewController.navigationItem.hidesBackButton = true
        contactViewController.navigationItem.leftBarButtonItem = nil
        contactViewController.navigationItem.rightBarButtonItem = nil
        contactViewController.navigationItem.title = ""
        
        return contactViewController
    }
    
    func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) {
        if uiViewController.isEditing != isEditing {
            uiViewController.setEditing(isEditing, animated: true)
        }
    }
}
