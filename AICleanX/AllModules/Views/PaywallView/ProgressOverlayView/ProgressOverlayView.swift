import SwiftUI

struct ProgressOverlayView: View {
    var body: some View {
        ZStack {
            // Фон, который не блокирует жесты, но дает легкий контраст
            Color.black.opacity(0.01) // Почти прозрачный фон, чтобы не блокировать UI
                .ignoresSafeArea()
            
            // Индикатор активности
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: CMColor.primary))
                .scaleEffect(1.5) // Делаем его немного крупнее
                .frame(width: 80, height: 80)
                .background(Color.white)
                .cornerRadius(10)
        }
        // ВАЖНО: .allowsHitTesting(false) позволяет жестам "проходить" сквозь оверлей
        .allowsHitTesting(false)
        .zIndex(100) // Убедитесь, что он поверх всего
    }
}
