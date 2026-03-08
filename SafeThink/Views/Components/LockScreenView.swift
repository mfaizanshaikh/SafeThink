import SwiftUI

struct LockScreenView: View {
    @StateObject private var security = SecurityService.shared
    @State private var pinInput = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLockedOut = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("SafeThink is Locked")
                .font(.title2)
                .bold()

            if security.isBiometricEnabled {
                Button {
                    Task {
                        let success = await security.authenticateWithBiometrics()
                        if !success {
                            showError = true
                            errorMessage = "Authentication failed"
                        }
                    }
                } label: {
                    Label("Unlock with \(security.biometricType)", systemImage: "faceid")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: 280)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            if security.isPINEnabled {
                VStack(spacing: 16) {
                    if security.isBiometricEnabled {
                        Text("or enter PIN")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // PIN dots
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { index in
                            Circle()
                                .fill(index < pinInput.count ? Color.accentColor : Color(.systemGray4))
                                .frame(width: 14, height: 14)
                        }
                    }

                    SecureField("Enter PIN", text: $pinInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .multilineTextAlignment(.center)
                        .onChange(of: pinInput) { _, newValue in
                            if newValue.count >= 4 {
                                let success = security.verifyPIN(newValue)
                                if !success {
                                    showError = true
                                    errorMessage = "Incorrect PIN"
                                    pinInput = ""
                                    if let lockout = security.lockoutDuration {
                                        isLockedOut = true
                                        errorMessage = "Too many attempts. Try again in \(Int(lockout))s"
                                        Task {
                                            try? await Task.sleep(for: .seconds(lockout))
                                            isLockedOut = false
                                        }
                                    }
                                }
                            }
                        }
                        .disabled(isLockedOut)
                }
            }

            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if security.isBiometricEnabled && !security.isAuthenticating {
                Task {
                    _ = await security.authenticateWithBiometrics()
                }
            }
        }
    }
}

#Preview {
    LockScreenView()
}
