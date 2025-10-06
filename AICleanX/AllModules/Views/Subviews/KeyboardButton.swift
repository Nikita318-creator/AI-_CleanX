import SwiftUI

struct KeyboardButton: View {
    let text: String
    let action: () -> Void
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 32 * scalingFactor, weight: .regular))
                .foregroundColor(CMColor.primaryText)
                .frame(width: 72 * scalingFactor, height: 72 * scalingFactor)
                .background(
                    Circle()
                        .fill(CMColor.surface)
                )
                .overlay(
                    Circle()
                        .stroke(CMColor.border, lineWidth: 1)
                )
        }
        .buttonStyle(KeypadButtonStyle())
    }
}
