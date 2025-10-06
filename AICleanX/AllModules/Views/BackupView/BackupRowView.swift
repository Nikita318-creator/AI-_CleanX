import SwiftUI

struct BackupRowView: View {
    let backup: BackupItem
    let scalingFactor: CGFloat
    let onTap: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        HStack(spacing: 16 * scalingFactor) {
            ZStack {
                RoundedRectangle(cornerRadius: 8 * scalingFactor)
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 44 * scalingFactor, height: 44 * scalingFactor)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 20 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
            
            VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                HStack {
                    Text(backup.dayOfWeek)
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primaryText)
                    
                    Spacer()
                    
                    Text(backup.dateString)
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                HStack {
                    Text("\(backup.contactsCount) contacts")
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                    
                    Spacer()
                    
                    Text(backup.size)
                        .font(.system(size: 14 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
            
            // Arrow icon
            Image(systemName: "chevron.right")
                .font(.system(size: 14 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 14 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(12 * scalingFactor)
        .shadow(color: CMColor.border.opacity(0.1), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
