
import SwiftUI

struct CustomProgressViewStyle: ProgressViewStyle {
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            // Фон
            RoundedRectangle(cornerRadius: 2 * scalingFactor)
                .fill(CMColor.backgroundSecondary)
                .frame(height: 4 * scalingFactor)
            
            // Прогресс
            RoundedRectangle(cornerRadius: 2 * scalingFactor)
                .fill(CMColor.primaryGradient)
                .frame(width: (configuration.fractionCompleted ?? 0) * UIScreen.main.bounds.width * 0.9)
                .frame(height: 4 * scalingFactor)
                .animation(.easeInOut(duration: 0.1), value: configuration.fractionCompleted)
        }
    }
}
