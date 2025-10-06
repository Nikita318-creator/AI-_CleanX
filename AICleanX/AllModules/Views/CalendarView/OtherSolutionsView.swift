import SwiftUI

struct OtherSolutionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerView()
                        .padding(.top, 20)
                    
                    // First Solution
                    firstSolutionView()
                    
                    // Second Solution
                    secondSolutionView()
                    
                    // Footer
                    footerView()
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
            .background(CMColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(CMColor.primary)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Instructions")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private func headerView() -> some View {
        VStack(spacing: 16) {
            Text("How to get rid of unwanted or suspicious calendars?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - First Solution View
    
    private func firstSolutionView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section title
            Text("First solution")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            // Steps
            VStack(alignment: .leading, spacing: 16) {
                stepView(
                    number: "1.",
                    text: "Open native Apple 'Calendar' app"
                )
                
                stepView(
                    number: "2.",
                    text: "Click the 'Calendars' link at the bottom of screen"
                )
                
                stepView(
                    number: "3.",
                    text: "Find the calendar you want to remove and tap \"Unsubscribe\" or \"Delete Calendar\" at the bottom of screen"
                )
            }
            
            // Action button
            Button(action: {
                openCalendarApp()
            }) {
                Text("Go to Calendar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.backgroundSecondary)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Second Solution View
    
    private func secondSolutionView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section title
            Text("Second solution")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            // Steps
            VStack(alignment: .leading, spacing: 16) {
                stepView(
                    number: "1.",
                    text: "Open 'Settings' app"
                )
                
                stepView(
                    number: "2.",
                    text: "Find 'Calendars' in the list and tap it"
                )
                
                stepView(
                    number: "3.",
                    text: "Go to 'Accounts'"
                )
                
                stepView(
                    number: "4.",
                    text: "Delete unwanted account"
                )
            }
            
            // Action button
            Button(action: {
                openSettingsApp()
            }) {
                Text("Go to Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.backgroundSecondary)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step View
    
    private func stepView(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
                .frame(width: 20, alignment: .leading)
            
            Text(text)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(CMColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Footer View
    
    private func footerView() -> some View {
        VStack(spacing: 8) {
            Text("Instructions by Apple")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(CMColor.secondaryText)
            
            // Home indicator line (как на скриншоте)
            Rectangle()
                .fill(CMColor.primaryText)
                .frame(width: 134, height: 5)
                .cornerRadius(2.5)
        }
    }
    
    // MARK: - Actions
    
    private func openCalendarApp() {
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "x-apple-calevent://") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
    
    private func openSettingsApp() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    OtherSolutionsView()
}
