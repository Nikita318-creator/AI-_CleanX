import SwiftUI
import LocalAuthentication

struct PINView: View {
    @State private var inputCode: String = ""
    @State private var codeFlowState: PinSetupState = .entry
    @State private var tempCode: String = ""
    @State private var displayError: Bool = false
    @State private var validationMessage: String = ""
    @State private var biometricAuthType: LABiometryType = .none
    @State private var isBiometricPromptAvailable: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - New State for Change Passcode Flow
    @State private var changePasscodeFlow: ChangePasscodeFlowState = .verifyingOldPin
    
    let requiredLength: Int = 4
    let onTabBarVisibilityChange: (Bool) -> Void
    let onCodeEntered: (String) -> Void
    let onBackButtonTapped: () -> Void
    let shouldAutoDismiss: Bool
    
    // MARK: - New Property
    let isChangingPasscode: Bool
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    enum PinSetupState {
        case setup
        case entry
        case confirm
    }
    
    // MARK: - New Enum
    enum ChangePasscodeFlowState {
        case verifyingOldPin
        case settingNewPin
        case confirmingNewPin
    }
    
    init(
        onTabBarVisibilityChange: @escaping (Bool) -> Void = { _ in },
        onCodeEntered: @escaping (String) -> Void = { _ in },
        onBackButtonTapped: @escaping () -> Void = { },
        shouldAutoDismiss: Bool = true,
        isChangingPasscode: Bool = false
    ) {
        self.onTabBarVisibilityChange = onTabBarVisibilityChange
        self.onCodeEntered = onCodeEntered
        self.onBackButtonTapped = onBackButtonTapped
        self.shouldAutoDismiss = shouldAutoDismiss
        self.isChangingPasscode = isChangingPasscode
    }
    
    var body: some View {
        ZStack {
            CMColor.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Redesigned Header with Back Button
                HStack {
                    Button(action: {
                        // Логика кнопки "Назад"
                        onBackButtonTapped()
                    }) {
                        HStack(spacing: 6 * scalingFactor) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(CMColor.primary)
                            
                            Text("Back")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(CMColor.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal, 16 * scalingFactor)
                .padding(.top, 30 * scalingFactor)
                
                Text(headerTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                    .padding(.top, 20 * scalingFactor)

                // MARK: - Description Text
                Text(screenDescription)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30 * scalingFactor)
                    .padding(.top, 10 * scalingFactor)
                
                Spacer()
                
                // MARK: - Redesigned PIN Code Section
                VStack(spacing: 32 * scalingFactor) {
                    HStack(spacing: 20 * scalingFactor) {
                        ForEach(0..<requiredLength, id: \.self) { index in
                            Circle()
                                .stroke(lineWidth: 2)
                                .fill(dotColor(for: index).opacity(0.5))
                                .frame(width: 16 * scalingFactor, height: 16 * scalingFactor)
                                .overlay(
                                    Circle()
                                        .fill(dotColor(for: index))
                                        .frame(width: 16 * scalingFactor, height: 16 * scalingFactor)
                                        .scaleEffect(index < inputCode.count ? 1.0 : 0.0)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: inputCode.count)
                                )
                                .animation(.easeInOut(duration: 0.2), value: displayError)
                        }
                    }
                    
                    if displayError {
                        Text(validationMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CMColor.error)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16 * scalingFactor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxHeight: 200)
                
                Spacer()
                
                // MARK: - Redesigned Keypad Section
                VStack(spacing: 24 * scalingFactor) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 36 * scalingFactor) {
                            ForEach(1...3, id: \.self) { column in
                                let number = row * 3 + column
                                KeyboardButton(
                                    text: "\(number)",
                                    action: { appendDigit("\(number)") }
                                )
                            }
                        }
                    }
                    
                    HStack(spacing: 36 * scalingFactor) {
                        if shouldShowBiometricPrompt {
                            Button(action: {
                                authenticateWithBiometrics()
                            }) {
                                Image(systemName: biometricIconName)
                                    .font(.system(size: 24 * scalingFactor, weight: .regular))
                                    .foregroundColor(CMColor.primaryText)
                                    .frame(width: 72 * scalingFactor, height: 72 * scalingFactor)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 72 * scalingFactor, height: 72 * scalingFactor)
                        }
                        
                        KeyboardButton(
                            text: "0",
                            action: { appendDigit("0") }
                        )
                        
                        Button(action: removeDigit) {
                            Image(systemName: "delete.backward.fill")
                                .font(.system(size: 24 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.primaryText)
                                .frame(width: 72 * scalingFactor, height: 72 * scalingFactor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(inputCode.isEmpty ? 0.3 : 1.0)
                        .disabled(inputCode.isEmpty)
                    }
                }
                .padding(.bottom, 64 * scalingFactor)
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            determineCodeState()
            checkBiometricAvailability()
            onTabBarVisibilityChange(false)
        }
        .onDisappear {
            onTabBarVisibilityChange(true)
        }
    }
    
    // MARK: - Helper Properties
    private var headerTitle: String {
        if isChangingPasscode {
            switch changePasscodeFlow {
            case .verifyingOldPin:
                return "Change Password"
            case .settingNewPin:
                return "Enter New PIN"
            case .confirmingNewPin:
                return "Confirm New PIN"
            }
        } else {
            switch codeFlowState {
            case .setup:
                return "Create Password"
            case .entry:
                return "Safe Storage"
            case .confirm:
                return "Confirm PIN"
            }
        }
    }
    
    private var screenDescription: String {
        if isChangingPasscode {
            switch changePasscodeFlow {
            case .verifyingOldPin:
                return "Enter your current PIN to continue"
            case .settingNewPin:
                return "Create a new 4-digit PIN"
            case .confirmingNewPin:
                return "Confirm your new PIN"
            }
        } else {
            switch codeFlowState {
            case .setup:
                return "Create a 4-digit PIN to secure your safe storage"
            case .entry:
                return "Enter your PIN to unlock"
            case .confirm:
                return "Confirm your 4-digit PIN"
            }
        }
    }
    
    private var shouldShowBiometricPrompt: Bool {
        return isBiometricPromptAvailable &&
                codeFlowState == .entry &&
                !isChangingPasscode
    }
    
    private var biometricIconName: String {
        switch biometricAuthType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "faceid"
        }
    }
    
    // MARK: - Helper Methods
    private func dotColor(for index: Int) -> Color {
        if displayError {
            return CMColor.error
        } else if index < inputCode.count {
            return CMColor.primary
        } else {
            return CMColor.secondaryText.opacity(0.3)
        }
    }
    
    private func hideError() {
        if displayError {
            withAnimation(.easeInOut(duration: 0.3)) {
                displayError = false
                validationMessage = ""
            }
        }
    }
    
    private func displayErrorState(message: String) {
        validationMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            displayError = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            hideError()
        }
    }
    
    private func appendDigit(_ digit: String) {
        guard inputCode.count < requiredLength else { return }
        
        hideError()
        inputCode += digit
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if inputCode.count == requiredLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                handleCompletedCode()
            }
        }
    }
    
    private func handleCompletedCode() {
        if isChangingPasscode {
            handlePasscodeChangeFlow()
        } else {
            handlePinSetupFlow()
        }
    }
    
    private func handlePinSetupFlow() {
        switch codeFlowState {
        case .setup:
            tempCode = inputCode
            codeFlowState = .confirm
            inputCode = ""
            
        case .confirm:
            if inputCode == tempCode {
                UserDefaults.standard.set(inputCode, forKey: "safe_storage_pin")
                onCodeEntered(inputCode)
                
                if shouldAutoDismiss {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } else {
                displayErrorState(message: "PINs don't match. Please try again.")
                inputCode = ""
                tempCode = ""
                codeFlowState = .setup
                
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
        case .entry:
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
            if inputCode == savedPin {
                onCodeEntered(inputCode)
                
                if shouldAutoDismiss {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } else {
                displayErrorState(message: "Incorrect PIN. Please try again.")
                inputCode = ""
                
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    private func handlePasscodeChangeFlow() {
        switch changePasscodeFlow {
        case .verifyingOldPin:
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
            if inputCode == savedPin {
                inputCode = ""
                withAnimation {
                    changePasscodeFlow = .settingNewPin
                }
            } else {
                displayErrorState(message: "Incorrect PIN. Please try again.")
                inputCode = ""
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
        case .settingNewPin:
            tempCode = inputCode
            inputCode = ""
            withAnimation {
                changePasscodeFlow = .confirmingNewPin
            }
            
        case .confirmingNewPin:
            if inputCode == tempCode {
                UserDefaults.standard.set(inputCode, forKey: "safe_storage_pin")
                onCodeEntered(inputCode)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } else {
                displayErrorState(message: "PINs don't match. Please try again.")
                inputCode = ""
                tempCode = ""
                withAnimation {
                    changePasscodeFlow = .settingNewPin
                }
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    private func determineCodeState() {
        if !isChangingPasscode {
            let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin")
            if savedPin == nil || savedPin?.isEmpty == true {
                codeFlowState = .setup
            } else {
                codeFlowState = .entry
            }
        }
        
        checkBiometricAvailability()
    }
    
    // MARK: - Biometric Authentication Methods
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricPromptAvailable = true
            biometricAuthType = context.biometryType
        } else {
            isBiometricPromptAvailable = false
            biometricAuthType = .none
        }
    }
    
    private func authenticateWithBiometrics() {
        guard isBiometricPromptAvailable else { return }
        
        let context = LAContext()
        let reason = "Use biometrics to access your secure storage."
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin") ?? ""
                    self.onCodeEntered(savedPin)
                    
                    if self.shouldAutoDismiss {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.dismiss()
                        }
                    }
                } else if let error = error {
                    self.handleBiometricError(error as NSError)
                }
            }
        }
    }
    
    private func handleBiometricError(_ error: NSError) {
        let message: String
        
        switch error.code {
        case LAError.biometryNotAvailable.rawValue:
            message = "Biometric authentication is not available."
        case LAError.biometryNotEnrolled.rawValue:
            message = "Biometric data is not configured."
        case LAError.biometryLockout.rawValue:
            message = "Biometrics is locked. Try again later."
        case LAError.userCancel.rawValue:
            return
        case LAError.userFallback.rawValue:
            return
        default:
            message = "Biometric authentication error."
        }
        
        displayErrorState(message: message)
    }
    
    private func removeDigit() {
        guard !inputCode.isEmpty else { return }
        
        hideError()
        inputCode.removeLast()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}
