import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerSelectableSystemContactRowView: View {
    let contact: CNContact
    let isSelected: Bool
    let isSelectionMode: Bool
    let scalingFactor: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16 * scalingFactor) {
                if isSelectionMode {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? CMColor.primary : CMColor.border, lineWidth: 2)
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
                }
                
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
            .background(isSelected ? CMColor.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
