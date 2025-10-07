import SwiftUI

// MARK: - MainTabBar (Neumorphism Style)
struct MainTabBar: View {
    @Binding var selectedTab: AICleanSpaceViewModel.TabType
    
    // Убираем scalingFactor
    
    var body: some View {
        VStack(spacing: 0) {
            // Убираем Divider, чтобы сделать таббар цельным
            
            HStack {
                ForEach(AICleanSpaceViewModel.TabType.allCases, id: \.self) { tab in
                    // Используем .frame(maxWidth: .infinity) вместо Spacer() для лучшего распределения
                    MainTabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        onTap: {
                            selectedTab = tab
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10) // Добавляем немного горизонтального отступа
            .padding(.top, 12)
            // ИСПОЛЬЗУЙТЕ GEOMETRY READER для SafeArea, чтобы корректно отступить от нижней грани
            .padding(.bottom, 34) // Используйте этот паддинг, если нет игнорирования SafeArea
            // .padding(.bottom, UIApplication.shared.windows.first?.safeAreaInsets.bottom == 0 ? 12 : 0)
        }
        .background(
            // Мягкий фон таббара с эффектом "приподнятости"
            ZStack {
                CMColor.backgroundSecondary // Сплошной базовый цвет
                
                // Эффект Неоморфизма: светлая тень сверху (имитация света)
                if #available(iOS 16.0, *) {
                    Rectangle()
                        .fill(CMColor.backgroundSecondary)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 20
                            )
                        )
                        .shadow(color: Color.white.opacity(0.1), radius: 3, x: 0, y: -3)
                } else {
                    Rectangle()
                        .fill(CMColor.backgroundSecondary)
                        .clipShape(.rect)
                        .shadow(color: Color.white.opacity(0.1), radius: 3, x: 0, y: -3)
                } // Светлая тень сверху
            }
            .ignoresSafeArea()
        )
    }
}
