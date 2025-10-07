import SwiftUI
import LocalAuthentication // Required for LAContext

// MARK: - 1. Utility Component: ShakeEffect
// The "shake" effect for visual display of input error
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Offset left-right by 8pt
        let x = sin(shakes * .pi * 2) * 8
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

// MARK: - 2. Utility Component: CodeInputCell
// Square cell to display a PIN code digit
struct CodeInputCell: View {
    let digit: Character?
    let isActive: Bool
    let isError: Bool
    
    // Scaling factor for adaptivity
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    private var borderColor: Color {
        if isError {
            return CMColor.error
        } else if isActive {
            return CMColor.primary
        } else {
            return CMColor.secondaryText.opacity(0.3)
        }
    }
    
    private var cellColor: Color {
        // Surface color to give depth
        return CMColor.surface
    }

    var body: some View {
        let size: CGFloat = 50 * scalingFactor
        
        Text(digit != nil ? String(digit!) : "")
            .font(.system(size: 28 * scalingFactor, weight: .bold))
            .foregroundColor(CMColor.primaryText)
            .frame(width: size, height: size)
            .background(cellColor)
            .cornerRadius(12 * scalingFactor)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scalingFactor)
                    .stroke(borderColor, lineWidth: isActive ? 3 : 2)
            )
            .shadow(color: CMColor.black.opacity(0.05), radius: 3, x: 0, y: 3)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .animation(.easeInOut(duration: 0.2), value: isError)
    }
}


// MARK: - 3. Utility Component: KeyboardButton
// Button with a neumorphic design (rounded square with shadows)
struct KeyboardButton: View {
    let text: String
    let action: () -> Void
    var size: CGFloat = 72
    
    @State private var isPressed: Bool = false
    
    private var buttonColor: Color {
        return CMColor.surface
    }
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: {
            action()
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isPressed = false
                }
            }
        }) {
            Text(text)
                .font(.system(size: 32 * scalingFactor, weight: .regular))
                .foregroundColor(CMColor.primaryText)
                .frame(width: size * scalingFactor, height: size * scalingFactor)
                .background(buttonColor)
                .clipShape(RoundedRectangle(cornerRadius: 20 * scalingFactor))
                // Outer shadow for "embossed" effect
                .shadow(color: CMColor.black.opacity(isPressed ? 0.05 : 0.15), radius: isPressed ? 3 : 8, x: isPressed ? 1 : 4, y: isPressed ? 1 : 4)
                // Light shadow for "depth" effect
                .shadow(color: CMColor.white.opacity(isPressed ? 0.0 : 0.6), radius: isPressed ? 3 : 8, x: isPressed ? -1 : -4, y: isPressed ? -1 : -4)
                // Inner stroke when pressed for "in-pressed" effect
                .overlay(
                    RoundedRectangle(cornerRadius: 20 * scalingFactor)
                        .stroke(isPressed ? CMColor.primary.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 20 * scalingFactor))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPressed)
    }
}


// MARK: - 4. Main Structure: PINView
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
                // MARK: - Header with Back Button
                HStack {
                    Button(action: {
                        // Back button logic
                        onBackButtonTapped()
                    }) {
                        HStack(spacing: 6 * scalingFactor) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(CMColor.primary)
                            
                            // *** NEW STRING ***
                            Text("Go Back")
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
                
                // MARK: - PIN Code Section (New Design with CodeInputCell)
                VStack(spacing: 32 * scalingFactor) {
                    HStack(spacing: 16 * scalingFactor) {
                        ForEach(0..<requiredLength, id: \.self) { index in
                            CodeInputCell(
                                // Pass the digit if it exists in inputCode
                                digit: index < inputCode.count ? inputCode[inputCode.index(inputCode.startIndex, offsetBy: index)] : nil,
                                // The cell is active if it contains an entered digit
                                isActive: index < inputCode.count,
                                isError: displayError
                            )
                        }
                    }
                    // Apply ShakeEffect to the entire row of cells on error
                    .modifier(ShakeEffect(shakes: displayError ? 2 : 0))
                    
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
                
                // MARK: - Keypad Section (New Design with KeyboardButton)
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
                                    // Update background and shape to match KeyboardButton style
                                    .background(CMColor.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 20 * scalingFactor))
                                    .shadow(color: CMColor.black.opacity(0.15), radius: 8, x: 4, y: 4)
                                    .shadow(color: CMColor.white.opacity(0.6), radius: 8, x: -4, y: -4)
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
                                // Update background and shape to match KeyboardButton style
                                .background(CMColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 20 * scalingFactor))
                                .shadow(color: CMColor.black.opacity(0.15), radius: 8, x: 4, y: 4)
                                .shadow(color: CMColor.white.opacity(0.6), radius: 8, x: -4, y: -4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(inputCode.isEmpty ? 0.5 : 1.0)
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
                // *** NEW STRING ***
                return "Update Secure Code"
            case .settingNewPin:
                // *** NEW STRING ***
                return "Establish New PIN"
            case .confirmingNewPin:
                // *** NEW STRING ***
                return "Verify New PIN"
            }
        } else {
            switch codeFlowState {
            case .setup:
                // *** NEW STRING ***
                return "Set Up Access Code"
            case .entry:
                // *** NEW STRING ***
                return "Protected Vault"
            case .confirm:
                // *** NEW STRING ***
                return "Confirm Access Code"
            }
        }
    }
    
    private var screenDescription: String {
        if isChangingPasscode {
            switch changePasscodeFlow {
            case .verifyingOldPin:
                // *** NEW STRING ***
                return "Input your existing security code to proceed."
            case .settingNewPin:
                // *** NEW STRING ***
                return "Choose a new 4-digit secret key."
            case .confirmingNewPin:
                // *** NEW STRING ***
                return "Please re-enter your new secret key."
            }
        } else {
            switch codeFlowState {
            case .setup:
                // *** NEW STRING ***
                return "Define a 4-digit code for your secure storage area."
            case .entry:
                // *** NEW STRING ***
                return "Enter your code to open the vault."
            case .confirm:
                // *** NEW STRING ***
                return "Confirm the 4-digit code you just created."
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
                // *** NEW STRING ***
                displayErrorState(message: "Codes do not match. Please restart setup.")
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
                // *** NEW STRING ***
                displayErrorState(message: "Invalid code entered. Please retry.")
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
                // *** NEW STRING ***
                displayErrorState(message: "Invalid current code. Access denied.")
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
                // *** NEW STRING ***
                displayErrorState(message: "Confirmation failed. New codes mismatch.")
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
        // *** NEW STRING ***
        let reason = "Authenticate with biometrics for secure access."
        
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
            // *** NEW STRING ***
            message = "Biometric recognition is unavailable on this device."
        case LAError.biometryNotEnrolled.rawValue:
            // *** NEW STRING ***
            message = "Your biometric identity is not set up."
        case LAError.biometryLockout.rawValue:
            // *** NEW STRING ***
            message = "Biometric access is temporarily disabled."
        case LAError.userCancel.rawValue:
            return
        case LAError.userFallback.rawValue:
            return
        default:
            // *** NEW STRING ***
            message = "An error occurred during biometric verification."
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

// Utility extension to get a character by index
extension StringProtocol {
    subscript(offset: Int) -> Element {
        self[self.index(startIndex, offsetBy: offset)]
    }
}
