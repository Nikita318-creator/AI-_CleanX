import SwiftUI

// MARK: - Tab Title Extension
extension AICleanSpaceViewModel.TabType {
    // Добавляем понятное название для каждой вкладки
    var tabTitle: String {
        switch self {
        case .clean: return "IceClean"
        case .dashboard: return "NetMonitor"
        case .safeFolder: return "Vault"
        }
    }
}

// MARK: - MainTabBarItem (Capsule Neumorphism Style)
struct MainTabBarItem: View {
    let tab: AICleanSpaceViewModel.TabType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            // MARK: - Родительский VStack
            VStack(spacing: 4) { // Увеличьте spacing, если нужно больше места между иконкой и текстом
                
                // MARK: - Капсула (Индикатор выбора)
                // Этот HStack будет содержать только иконку
                HStack(spacing: 8) {
                    Image(systemName: systemImageName(for: tab))
                    // Используем более смелый вес шрифта
                        .font(.system(size: 20, weight: .bold))
                    // Цвет иконки меняется в зависимости от выбора
                        .foregroundColor(isSelected ? CMColor.white : CMColor.iconSecondary)
                    
                    // Убрали текст из HStack!
                }
                // Настройки фона и паддинга для КОРПУСА КАПСУЛЫ
                .padding(.horizontal, isSelected ? 16 : 0) // Увеличенный padding для выбранной капсулы
                .padding(.vertical, 8)
                .frame(minHeight: 44) // Фиксированная высота для удобства тапа (для капсулы)
                .background(
                    ZStack {
                        if isSelected {
                            Capsule() // Контейнер-капсула для активного элемента
                                .fill(CMColor.primary)
                                .shadow(color: CMColor.primary.opacity(0.5), radius: 6, x: 0, y: 3)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                )
                // Обеспечиваем, чтобы неактивные элементы занимали то же пространство
                // .frame(maxWidth: .infinity) // Можно убрать .frame(maxWidth: .infinity) здесь, так как он есть во внешнем MainTabBar
                
                // MARK: - ТЕКСТ ПОД ИКОНКОЙ
                Text(tab.tabTitle)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium)) // Более мелкий шрифт для текста
                    .foregroundColor(isSelected ? CMColor.primary : CMColor.iconSecondary) // Цвет текста
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
    
    private func systemImageName(for tab: AICleanSpaceViewModel.TabType) -> String {
        // --- ОБНОВЛЕННЫЕ ИКОНКИ ---
        switch tab {
        case .clean:
            // Иконка для быстрой очистки/защиты
            return isSelected ? "bolt.shield.fill" : "bolt.shield"
        case .dashboard:
            // Иконка для аналитики/обзора
            // Используем chart.bar.fill, так как это более "отчетливая" иконка для дашборда
            return "chart.bar.fill"
        case .safeFolder:
            // Иконка для защищенной папки (более детализирована)
            return "lock.square.fill"
        }
    }
}
