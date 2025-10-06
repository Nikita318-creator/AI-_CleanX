import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerContactCardWithCustomNavView: View {
    let contact: CNContact
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(CMColor.primary)
                        
                        Text("Contacts")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(CMColor.primary)
                    }
                }
                .padding(.leading, 16)
                
                Spacer()
                
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(CMColor.primary)
                .padding(.trailing, 16)
            }
            .frame(height: 44)
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(UIColor.separator)),
                alignment: .bottom
            )
            
            ContactCardPushViewRepresentable(contact: contact, isEditing: $isEditing)
                .navigationBarHidden(true)
        }
        .navigationBarHidden(true)
    }
}
