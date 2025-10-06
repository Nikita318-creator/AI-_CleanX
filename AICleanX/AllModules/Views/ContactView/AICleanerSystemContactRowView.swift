import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerSystemContactRowView: View {
    let contact: CNContact
    let scalingFactor: CGFloat
    
    var body: some View {
        HStack(spacing: 16 * scalingFactor) {
            // Contact Initial Circle
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 50 * scalingFactor, height: 50 * scalingFactor)
                
                Text(String(contact.givenName.prefix(1)).uppercased())
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            }
            
            VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                Text("\(contact.givenName) \(contact.familyName)")
                    .font(.system(size: 17 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                    Text(phoneNumber)
                        .font(.system(size: 15 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 16 * scalingFactor)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}
