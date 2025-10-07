import SwiftUI

// MARK: - Tab Title Extension
extension AICleanSpaceViewModel.TabType {
    // Добавляем понятное название для каждой вкладки
    var tabTitle: String {
        switch self {
        case .clean: return "Clean"
        case .dashboard: return "Dashboard"
        case .star: return "Favorites"
        case .safeFolder: return "Safe Folder"
        case .backup: return "Backup"
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
            VStack(spacing: 4) {
                // MARK: - Капсула (Индикатор выбора)
                HStack(spacing: 8) {
                    Image(systemName: systemImageName(for: tab))
                        // Используем более смелый вес шрифта
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isSelected ? CMColor.white : CMColor.iconSecondary)
                    
                    // Добавляем текст, который виден только при выборе
//                    if isSelected {
//                        Text(tab.tabTitle)
//                            .font(.system(size: 14, weight: .bold))
//                            .foregroundColor(CMColor.white)
//                            .lineLimit(1)
//                            .minimumScaleFactor(0.8)
//                    }
                }
                .padding(.horizontal, isSelected ? 16 : 0) // Увеличенный padding для выбранной капсулы
                .padding(.vertical, 8)
                .frame(minHeight: 44) // Фиксированная высота для удобства тапа
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
                .frame(maxWidth: .infinity)
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
        case .star:
            // Иконка для избранного (более строгая, квадратная)
            return isSelected ? "star.square.fill" : "star.square"
        case .safeFolder:
            // Иконка для защищенной папки (более детализирована)
            return "lock.square.fill"
        case .backup:
            // Иконка для облачного хранилища/бэкапа
            return "cloud.fill"
        }
    }
}
