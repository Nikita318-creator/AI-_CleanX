import SwiftUI
import Photos
// Возможно, потребуется импорт для VisualEffectView, например:
// import CustomUIComponents

struct ResultsAIFeatureSwipePopup: View {
    let deleteCount: Int
    @Binding var isPresented: Bool
    let onViewResults: () -> Void
    let onContinueSwiping: () -> Void
    
    @State private var showContent = false
    @State private var backgroundOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Предполагается, что CMColor.black и VisualEffectView доступны
            CMColor.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            // Заглушка для VisualEffectView, если она не определена в этом scope
            // Если VisualEffectView определена, используйте ее:
            // VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            Color.clear // Заменил на Color.clear для билда, если VisualEffectView неизвестна
                .background(.ultraThinMaterial) // Использование стандартного эффекта размытия SwiftUI
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [CMColor.primary.opacity(0.2), CMColor.accent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .shadow(color: CMColor.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CMColor.primary, CMColor.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 8) {
                        // ИЗМЕНЕНИЕ: Акцент на завершении AI-скана
                        Text("AI Scan Phase Complete!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(CMColor.primaryText)
                            .multilineTextAlignment(.center)
                        
                        // ИЗМЕНЕНИЕ: Акцент на том, что AI пометил файлы как "clutter"
                        Text("The AI analysis marked \(deleteCount) photo\(deleteCount == 1 ? "" : "s") as clutter. Review the cleanup recommendations?")
                            .font(.body)
                            .foregroundColor(CMColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                
                VStack(spacing: 12) {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showContent = false
                            backgroundOpacity = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onViewResults()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 16, weight: .semibold))
                                
                            // ИЗМЕНЕНИЕ: Профессиональный CTA
                            Text("View AI Cleanup Report (\(deleteCount) Items)")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(CMColor.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [CMColor.primary, CMColor.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: CMColor.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showContent)
                    
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismissPopup()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                
                            // ИЗМЕНЕНИЕ: Четкое действие для закрытия
                            Text("Continue Swiping")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(CMColor.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: showContent)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    // Использую .regularMaterial для билда, если CMColor.regularMaterial не определен
                    .fill(.regularMaterial)
                    .shadow(color: CMColor.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            .scaleEffect(showContent ? 1 : 0.7)
            .opacity(showContent ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showContent)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                backgroundOpacity = 0.4
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    private func dismissPopup() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        onContinueSwiping()
    }
}
