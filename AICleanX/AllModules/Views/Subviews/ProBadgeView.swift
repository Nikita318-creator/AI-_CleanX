
import SwiftUI

struct ProBadgeView: View {
    @StateObject private var viewModel = AICleanSpaceViewModel()
    @Binding var isPaywallPresented: Bool

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: {
            isPaywallPresented = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(CMColor.primaryLight)
                
                Text("Pro")
                    .fontWeight(.semibold)
                    .foregroundColor(CMColor.primaryLight)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(CMColor.backgroundSecondary)
            .clipShape(Capsule())
        }
    }
}

