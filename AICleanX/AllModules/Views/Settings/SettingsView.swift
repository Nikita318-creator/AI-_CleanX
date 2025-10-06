import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isPaywallPresented: Bool
    
    @StateObject private var viewModel = SettingsViewModel()
    
    // MARK: - Navigation state
    @State private var showBackupView: Bool = false
    @State private var showChangePasscodeView: Bool = false

    private var contentScalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32 * contentScalingFactor) {
                settingsPageHeader
                
//                securityAndPrivacySection
                
                secretVaultSection
                
                aboutAppSection
            }
            .padding(.horizontal, 20 * contentScalingFactor)
            .padding(.bottom, 100 * contentScalingFactor)
        }
        .background(CMColor.backgroundSecondary)
        .fullScreenCover(isPresented: $showBackupView) {
            BackupView()
        }
        .fullScreenCover(isPresented: $showChangePasscodeView) {
            PINView(
                onTabBarVisibilityChange: { _ in },
                onCodeEntered: { code in
                    print("New passcode saved: \(code)")
                },
                onBackButtonTapped: {
                    showChangePasscodeView = false
                },
                shouldAutoDismiss: true,
                isChangingPasscode: true
            )
        }
    }
    
    // MARK: - Settings Header Section
    private var settingsPageHeader: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                    .padding(10)
                    .background(CMColor.surface)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Settings")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
        }
        .padding(.top, 20 * contentScalingFactor)
    }

    // MARK: - Security & Privacy Section
    private var securityAndPrivacySection: some View {
        VStack(alignment: .leading, spacing: 16 * contentScalingFactor) {
            Text("Security & Privacy")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .padding(.leading, 10 * contentScalingFactor)
            
            VStack(spacing: 1 * contentScalingFactor) {
                // Ячейка для "Enable passcode in app"
                SecurityToggleRow(
                    title: "Enable passcode in app",
                    isOn: $viewModel.isPasscodeEnabledInApp
                )
                
                // Ячейка для "Change passcode"
                SecurityNavigationRow(
                    title: "Change passcode",
                    action: { showChangePasscodeView = true }
                )
                .disabled(!viewModel.isPasscodeEnabledInApp)
                .opacity(viewModel.isPasscodeEnabledInApp ? 1.0 : 0.5)
                
                // Ячейка для "Face ID in app"
                SecurityToggleRow(
                    title: "Face ID in app",
                    isOn: $viewModel.isFaceIDInAppEnabled
                )
                .disabled(!viewModel.isPasscodeEnabledInApp)
                .opacity(viewModel.isPasscodeEnabledInApp ? 1.0 : 0.5)
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20 * contentScalingFactor, style: .continuous))
            .shadow(color: CMColor.primary.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Private Vault Section
    private var secretVaultSection: some View {
        VStack(alignment: .leading, spacing: 16 * contentScalingFactor) {
            Text("Private Vault")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .padding(.leading, 10 * contentScalingFactor)
            
            VStack(spacing: 1 * contentScalingFactor) {
                // Ячейка для "Change passcode"
                SecurityNavigationRow(
                    title: "Change passcode",
                    action: { showChangePasscodeView = true }
                )
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20 * contentScalingFactor, style: .continuous))
            .shadow(color: CMColor.primary.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }

    // MARK: - About App Section
    private var aboutAppSection: some View {
        VStack(alignment: .leading, spacing: 16 * contentScalingFactor) {
            Text("About")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .padding(.leading, 10 * contentScalingFactor)
            
            VStack(spacing: 1 * contentScalingFactor) {
                // Ячейка для "License agreement"
                AboutNavigationRow(
                    title: "License agreement",
                    action: { viewModel.licenseAgreementTapped() }
                )
                
                // Ячейка для "Privacy policy"
                AboutNavigationRow(
                    title: "Privacy policy",
                    action: { viewModel.privacyPolicyTapped() }
                )
                
                // Ячейка для "Send feedback"
                AboutNavigationRow(
                    title: "Send feedback",
                    action: { viewModel.sendFeedbackTapped() }
                )
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20 * contentScalingFactor, style: .continuous))
            .shadow(color: CMColor.primary.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}

private struct SecurityToggleRow: View {
    var title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(CMColor.primaryText)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(CMColor.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
}

private struct SecurityNavigationRow: View {
    var title: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CMColor.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(CMColor.iconSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
}

private struct AboutNavigationRow: View {
    var title: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CMColor.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(CMColor.iconSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
}
