import SwiftUI

struct CleanerNextLevelView: View {
    @StateObject private var viewModel = AICleanSpaceViewModel()
    @StateObject private var safeStorageManager = SafeStorageManager()
    @State private var isTabBarVisible: Bool = true
    @State private var isPasswordSet: Bool = false
    @State private var isSafeFolderUnlocked: Bool = false
    @State private var isPaywallPresented: Bool = false

    @AppStorage("paywallShown") var paywallShown: Bool = false

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }

    var body: some View {
        ZStack {
            CMColor.background
                .ignoresSafeArea()
            
            if paywallShown {
                VStack(spacing: 0) {
                    switch viewModel.currentSelectedTab {
                    case .clean:
                        MainView(isPaywallPresented: $isPaywallPresented)
                    case .dashboard:
                        SpeedTestView(isPaywallPresented: $isPaywallPresented)                        
                    case .safeFolder:
                        safeFolder
                    }
                }
                .onChange(of: viewModel.currentSelectedTab) { newValue in
                    if newValue != .safeFolder {
                        isSafeFolderUnlocked = false
                    }
                }
            }

            if isTabBarVisible {
                VStack {
                    Spacer()
                    
                    MainTabBar(selectedTab: $viewModel.currentSelectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .edgesIgnoringSafeArea(.bottom) // <--- ДОБАВЛЕНО/ИЗМЕНЕНО: Таббар должен игнорировать нижнюю safe area
            }
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView(isPresented: $isPaywallPresented)
                .onDisappear {
                    paywallShown = true
                }
        }
        .onAppear {
            if !paywallShown {
                isPaywallPresented = true
            }
        }
    }
    
    // MARK: - Новый экран: Safe Folder
    private var safeFolder: some View {
        Group {
            if !isSafeFolderUnlocked {
                PINView(
                    onTabBarVisibilityChange: { isVisible in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isTabBarVisible = isVisible
                        }
                    },
                    onCodeEntered: { code in
                        print("PIN entered: \(code)")
                        isSafeFolderUnlocked = true
                    },
                    onBackButtonTapped: {
                        viewModel.currentSelectedTab = .clean
                    },
                    shouldAutoDismiss: false
                )
            } else {
                SafeStorageView(isPaywallPresented: $isPaywallPresented)
            }
        }
        .onAppear {
            checkPasswordStatus()
        }
        .environmentObject(safeStorageManager)
    }
    
    // MARK: - Helper Methods
    private func checkPasswordStatus() {
        let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin")
        isPasswordSet = savedPin != nil && !savedPin!.isEmpty
    }
}
