
import SwiftUI

// MARK: - Event Row View
struct EventRowView: View {
    let event: CalendarEvent
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Checkbox
            Button(action: onSelect) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? .clear : CMColor.border, lineWidth: 2)
                        .background(isSelected ? CMColor.primary : .clear)
                        .clipShape(Circle())
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Event Info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(event.source)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
            
            // Event Date
            Text(event.formattedDate)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(CMColor.secondaryText)
        }
        .padding(.vertical, 16)
    }
}
