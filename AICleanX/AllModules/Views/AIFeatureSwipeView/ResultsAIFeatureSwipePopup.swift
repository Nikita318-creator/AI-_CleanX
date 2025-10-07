import SwiftUI
import Photos
import UIKit // Для UIImpactFeedbackGenerator
// import CustomUIComponents // Предполагается, что здесь объявлен VisualEffectView

struct ResultsAIFeatureSwipePopup: View {
    let deleteCount: Int
    @Binding var isPresented: Bool
    let onViewResults: () -> Void
    let onContinueSwiping: () -> Void
    
    @State private var showContent = false
    @State private var backgroundOpacity = 0.0
    
    // Новая функция для закрытия и продолжения свайпинга
    private func dismissPopup() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.easeIn(duration: 0.2)) {
            backgroundOpacity = 0
            showContent = false
        }
        
        // 1. Сначала установить привязку в false, чтобы скрыть попап
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isPresented = false // <--- ДОБАВЬТЕ ЭТО
        }
        
        // 2. Затем вызвать onContinueSwiping() (что, вероятно, просто сигнализирует родителю о продолжении свайпа)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            onContinueSwiping() // <--- Этот экшн должен только переходить к следующему элементу свайпа, НО НЕ ЗАКРЫВАТЬ ВЕСЬ ЭКРАН.
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) { // ПРИВЯЗКА КАРТОЧКИ К НИЗУ ЭКРАНА
            
            // 1. Легкий оверлей (затемнение фона)
            CMColor.black // ИСПОЛЬЗУЕМ ВАШ ГЛОБАЛЬНЫЙ ЦВЕТ
                .opacity(backgroundOpacity * 0.4) // Уменьшаем непрозрачность затемнения
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            // 2. Карточка-баннер (Bottom Sheet)
            VStack(spacing: 24) {
                
                // --- Секция Заголовка и Описания (HStack для выравнивания по левому краю) ---
                HStack(alignment: .top, spacing: 12) {
                    
                    // Иконка: Простой акцент
                    Image(systemName: "sparkles") // Новый, более минималистичный символ
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(CMColor.accent) // ИСПОЛЬЗУЕМ ВАШ ЦВЕТ
                        .padding(.top, 2)
                        
                    // Текстовый блок (выравнивание по левому краю)
                    VStack(alignment: .leading, spacing: 4) {
                        
                        // Новый заголовок
                        Text("Cleanup Ready! 🚀")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(CMColor.primaryText) // ИСПОЛЬЗУЕМ ВАШ ЦВЕТ
                            .multilineTextAlignment(.leading)
                        
                        // Новый подзаголовок
                        Text("AI found \(deleteCount) potential clutter photo\(deleteCount == 1 ? "" : "s"). Review and confirm removal now?")
                            .font(.subheadline)
                            .foregroundColor(CMColor.secondaryText) // ИСПОЛЬЗУЕМ ВАШ ЦВЕТ
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                    
                    Spacer(minLength: 0)
                }

                // --- Секция Кнопок (CTA) ---
                VStack(spacing: 8) {
                    
                    // 1. Основная кнопка (Review & Clean Up)
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        withAnimation(.easeIn(duration: 0.2)) {
                            backgroundOpacity = 0
                            showContent = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onViewResults()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill") // Новая, более подходящая иконка
                                .font(.system(size: 16, weight: .semibold))
                            Text("Review & Clean Up (\(deleteCount))") // Новый текст
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(CMColor.white) // ИСПОЛЬЗУЕМ ВАШ ЦВЕТ
                        .frame(maxWidth: .infinity)
                        .frame(height: 52) // Более тонкая кнопка
                        .background(
                            LinearGradient(
                                colors: [CMColor.primary, CMColor.accent], // ИСПОЛЬЗУЕМ ВАШИ ЦВЕТА
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: CMColor.primary.opacity(0.4), radius: 8, x: 0, y: 4) // ИСПОЛЬЗУЕМ ВАШ ЦВЕТ
                    }
                    
                    // 2. Вторичная кнопка (Continue Swiping)
                    Button {
                        dismissPopup()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.forward.square.fill") // Новая иконка
                                .font(.system(size: 16, weight: .medium))
                            Text("Not Now, Continue Swiping") // Новый текст
                                .font(.body)
                                .fontWeight(.regular)
                        }
                        .foregroundColor(CMColor.secondaryText) // ИСПОЛЬЗУЕМ ВАШ ЦВЕТ
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(CMColor.backgroundSecondary.opacity(0.5)) // ИСПОЛЬЗУЕМ ВАШ ЦВЕТ (с меньшей непрозрачностью)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .scaleEffect(showContent ? 1 : 0.9) // Легкая анимация контента
                .opacity(showContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showContent)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 40) // Отступ от безопасной зоны
            .background(
                // Фон карточки
                RoundedRectangle(cornerRadius: 24)
                    // Используем стандартный эффект для "regularMaterial", так как CMColor.regularMaterial не определен
                    .fill(.regularMaterial)
                    .shadow(color: CMColor.black.opacity(0.15), radius: 10, x: 0, y: -5) // ИСПОЛЬЗУЕМ ВАШ ЦВЕТ
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            // Анимация: Смещение снизу вверх (выглядит СИЛЬНО по-другому)
            .offset(y: showContent ? 0 : 300)
            .opacity(showContent ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.9), value: showContent)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                backgroundOpacity = 1.0 // Устанавливаем полную видимость оверлея
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9).delay(0.1)) {
                showContent = true
            }
        }
    }
}
