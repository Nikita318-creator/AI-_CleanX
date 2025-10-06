import SwiftUI
import Contacts

struct AICleanerIncompleteContactRow: View {
    let contact: CNContact
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка контакта с инициалами
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.6))
                    .frame(width: 44, height: 44)
                
                Text(String(contact.givenName.prefix(1).uppercased()))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Имя и фамилия
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                Text(fullName.isEmpty ? "No Name" : fullName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(CMColor.primaryText)
                
                // Телефон, email или название организации
                if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                    Text(phoneNumber)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                } else if let email = contact.emailAddresses.first?.value as? String {
                    Text(email)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                } else if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.right")
                .foregroundColor(CMColor.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(CMColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CMColor.border, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }
}
