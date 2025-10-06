import SwiftUI

struct MainTabBar: View {
    @Binding var selectedTab: AICleanSpaceViewModel.TabType
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(CMColor.border)
            
            HStack {
                ForEach(AICleanSpaceViewModel.TabType.allCases, id: \.self) { tab in
                    Spacer()
                    MainTabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        onTap: {
                            selectedTab = tab
                        }
                    )
                    Spacer()
                }
            }
            .padding(.top, 12 * scalingFactor)
            .padding(.bottom, 34 * scalingFactor)
        }
        .background(
            Color.clear.background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}
