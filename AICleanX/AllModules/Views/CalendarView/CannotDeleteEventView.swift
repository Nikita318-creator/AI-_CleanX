import SwiftUI

struct CannotDeleteEventView: View {
    let eventTitle: String
    let message: String
    let onGuide: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Main popup
            VStack(spacing: 0) {
                // Header with calendar icon
                VStack(spacing: 16) {
                    // Calendar icon with email
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(CMColor.primary)
                        
                        Text(eventTitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(CMColor.primaryText)
                            .lineLimit(1)
                    }
                    .padding(.top, 24)
                    
                    // Warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                        .padding(.vertical, 8)
                }
                
                // Message content
                VStack(spacing: 16) {
                    Text("'\(eventTitle)' calendar cannot be deleted.")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Text("But you can delete the account that owns this calendar. You can learn detailed steps from our guide on how to get rid of suspicious or unwanted event sources in your calendar.")
                        .font(.system(size: 15))
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                
                // Divider
                Divider()
                    .background(CMColor.border)
                
                // Action buttons
                HStack(spacing: 0) {
                    // Guide button
                    Button(action: onGuide) {
                        Text("Guide")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(CMColor.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    
                    // Vertical divider
                    Divider()
                        .background(CMColor.border)
                        .frame(height: 48)
                    
                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .background(CMColor.surface)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Preview

#Preview {
    CannotDeleteEventView(
        eventTitle: "m.polous@netteca.com",
        message: "This calendar cannot be deleted. But you can delete the account that owns this calendar.",
        onGuide: {
            print("Guide tapped")
        },
        onCancel: {
            print("Cancel tapped")
        }
    )
}
