import SwiftUI

struct MainTabBarItem: View {
    let tab: AICleanSpaceViewModel.TabType
    let isSelected: Bool
    let onTap: () -> Void
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4 * scalingFactor) {
                if isSelected {
                    Rectangle()
                        .fill(CMColor.primary)
                        .frame(width: 32 * scalingFactor, height: 2)
                        .cornerRadius(1)
                        .padding(.top, 2 * scalingFactor)
                        .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)
                        .padding(.top, 2 * scalingFactor)
                }
                
                Image(systemName: systemImageName(for: tab))
                    .font(.system(size: 24 * scalingFactor, weight: .regular))
                    .foregroundColor(isSelected ? CMColor.primary : CMColor.iconSecondary)
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func systemImageName(for tab: AICleanSpaceViewModel.TabType) -> String {
        switch tab {
        case .clean:
            return "paintbrush"
        case .dashboard:
            return "rectangle.grid.1x2.fill"
        case .star:
            return "heart"
        case .safeFolder:
            return "lock.fill"
        case .backup:
            return "tray.and.arrow.down"
        }
    }
}

extension AICleanSpaceViewModel.TabType {
    var iconName: String {
        switch self {
        case .clean: return "paintbrush"
        case .dashboard: return "rectangle.grid.1x2.fill"
        case .star: return "heart"
        case .safeFolder: return "lock.fill"
        case .backup: return "tray.and.arrow.down"
        }
    }
}
