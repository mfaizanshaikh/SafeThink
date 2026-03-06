import SwiftUI

struct SecuritySettingsView: View {
    @StateObject private var security = SecurityService.shared
    @State private var showPINSetup = false
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var pinError = ""

    var body: some View {
        Form {
            Section("Biometrics") {
                Toggle(security.biometricType, isOn: $security.isBiometricEnabled)
            }

            Section("PIN Lock") {
                if security.isPINEnabled {
                    Button("Change PIN") {
                        showPINSetup = true
                    }
                    Button("Remove PIN", role: .destructive) {
                        security.removePIN()
                    }
                } else {
                    Button("Set PIN") {
                        showPINSetup = true
                    }
                }
            }

            Section("Lock Timeout") {
                Picker("Lock After", selection: $security.lockTimeout) {
                    ForEach(SecurityService.LockTimeout.allCases, id: \.self) { timeout in
                        Text(timeout.displayName).tag(timeout)
                    }
                }
            }

            Section("Self-Destruct") {
                Toggle("Enable Self-Destruct", isOn: $security.selfDestructEnabled)
                if security.selfDestructEnabled {
                    Stepper("After \(security.selfDestructAttempts) failed attempts",
                            value: $security.selfDestructAttempts, in: 5...20)
                    Text("Deletes all chats and data (not models) after too many failed PIN attempts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Security")
        .sheet(isPresented: $showPINSetup) {
            NavigationStack {
                Form {
                    Section("Enter PIN") {
                        SecureField("New PIN (4-6 digits)", text: $newPIN)
                            .keyboardType(.numberPad)
                        SecureField("Confirm PIN", text: $confirmPIN)
                            .keyboardType(.numberPad)
                        if !pinError.isEmpty {
                            Text(pinError)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
                .navigationTitle("Set PIN")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            resetPINFields()
                            showPINSetup = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            savePIN()
                        }
                        .disabled(newPIN.count < 4)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func savePIN() {
        guard newPIN.count >= 4 && newPIN.count <= 6 else {
            pinError = "PIN must be 4-6 digits"
            return
        }
        guard newPIN.allSatisfy(\.isNumber) else {
            pinError = "PIN must contain only digits"
            return
        }
        guard newPIN == confirmPIN else {
            pinError = "PINs don't match"
            return
        }

        security.setPIN(newPIN)
        resetPINFields()
        showPINSetup = false
    }

    private func resetPINFields() {
        newPIN = ""
        confirmPIN = ""
        pinError = ""
    }
}

#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
}
