
import SwiftUI

// MARK: - Компонент для строк настроек (Исправленный)
struct SettingsRow: View {
    let title: String
    var icon: String? = nil
    var isToggle: Bool = false
    @Binding var isOn: Bool
    var isNavigation: Bool = false
    var isFirst: Bool = false
    var isLast: Bool = false
    var action: (() -> Void)? = nil // Closure for tap action

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            if isToggle {
                Toggle(isOn: $isOn) {
                    EmptyView()
                }
                .toggleStyle(SwitchToggleStyle(tint: CMColor.primary))
            } else if isNavigation {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(CMColor.tertiaryText)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(CMColor.surface)
        .contentShape(Rectangle()) // Make the whole row tappable
        .onTapGesture {
            if isToggle {
                // Toggling the state when the row is tapped
                isOn.toggle()
            } else {
                // Execute the action for navigation/tap
                action?()
            }
        }
    }
}

