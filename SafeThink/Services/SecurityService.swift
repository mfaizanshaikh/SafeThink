import Foundation
import LocalAuthentication
import Security
import CommonCrypto

@MainActor
final class SecurityService: ObservableObject {
    static let shared = SecurityService()

    @Published var isAuthenticated = false
    @Published var isBiometricEnabled = false
    @Published var isPINEnabled = false
    @Published var lockTimeout: LockTimeout = .immediate
    @Published var selfDestructEnabled = false
    @Published var selfDestructAttempts = 10

    private var failedAttempts = 0
    private var lastAuthTime: Date?

    enum LockTimeout: Int, CaseIterable {
        case immediate = 0
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300
        case never = -1

        var displayName: String {
            switch self {
            case .immediate: return "Immediately"
            case .thirtySeconds: return "30 seconds"
            case .oneMinute: return "1 minute"
            case .fiveMinutes: return "5 minutes"
            case .never: return "Never"
            }
        }
    }

    private init() {
        loadSettings()
    }

    // MARK: - Biometric Auth

    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock SafeThink"
            )
            if success {
                isAuthenticated = true
                lastAuthTime = Date()
            }
            return success
        } catch {
            return false
        }
    }

    var biometricType: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }

    // MARK: - PIN

    func setPIN(_ pin: String) {
        let salt = generateSalt()
        guard let hash = hashPIN(pin, salt: salt) else { return }

        saveToKeychain(key: "pin_hash", data: hash)
        saveToKeychain(key: "pin_salt", data: salt)
        isPINEnabled = true
        saveSettings()
    }

    func verifyPIN(_ pin: String) -> Bool {
        guard let storedHash = loadFromKeychain(key: "pin_hash"),
              let salt = loadFromKeychain(key: "pin_salt") else {
            return false
        }

        guard let inputHash = hashPIN(pin, salt: salt) else { return false }

        if inputHash == storedHash {
            failedAttempts = 0
            isAuthenticated = true
            lastAuthTime = Date()
            return true
        } else {
            failedAttempts += 1
            if selfDestructEnabled && failedAttempts >= selfDestructAttempts {
                performSelfDestruct()
            }
            return false
        }
    }

    func removePIN() {
        deleteFromKeychain(key: "pin_hash")
        deleteFromKeychain(key: "pin_salt")
        isPINEnabled = false
        saveSettings()
    }

    var lockoutDuration: TimeInterval? {
        switch failedAttempts {
        case 0..<5: return nil
        case 5: return 30
        case 6: return 60
        default: return 300
        }
    }

    // MARK: - Lock State

    func checkLockState() {
        guard lockTimeout != .never else {
            isAuthenticated = true
            return
        }

        guard isBiometricEnabled || isPINEnabled else {
            isAuthenticated = true
            return
        }

        if lockTimeout == .immediate {
            isAuthenticated = false
            return
        }

        if let lastAuth = lastAuthTime {
            let elapsed = Date().timeIntervalSince(lastAuth)
            if elapsed > TimeInterval(lockTimeout.rawValue) {
                isAuthenticated = false
            }
        } else {
            isAuthenticated = false
        }
    }

    func lock() {
        isAuthenticated = false
    }

    // MARK: - Self-Destruct

    private func performSelfDestruct() {
        try? DatabaseService.shared.deleteAllData()
        // Delete documents
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("documents")
        try? FileManager.default.removeItem(at: docsDir)
        failedAttempts = 0
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.safethink.security",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.safethink.security",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.safethink.security"
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - PIN Hashing (PBKDF2)

    private func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        return salt
    }

    private func hashPIN(_ pin: String, salt: Data) -> Data? {
        guard let pinData = pin.data(using: .utf8) else { return nil }
        var derivedKey = Data(count: 32)
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                pinData.withUnsafeBytes { pinBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pinBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        pinData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        100_000,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        return result == kCCSuccess ? derivedKey : nil
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        UserDefaults.standard.set(isBiometricEnabled, forKey: "security_biometric")
        UserDefaults.standard.set(isPINEnabled, forKey: "security_pin")
        UserDefaults.standard.set(lockTimeout.rawValue, forKey: "security_timeout")
        UserDefaults.standard.set(selfDestructEnabled, forKey: "security_selfdestruct")
        UserDefaults.standard.set(selfDestructAttempts, forKey: "security_selfdestruct_attempts")
    }

    private func loadSettings() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: "security_biometric")
        isPINEnabled = UserDefaults.standard.bool(forKey: "security_pin")
        let timeoutRaw = UserDefaults.standard.integer(forKey: "security_timeout")
        lockTimeout = LockTimeout(rawValue: timeoutRaw) ?? .immediate
        selfDestructEnabled = UserDefaults.standard.bool(forKey: "security_selfdestruct")
        selfDestructAttempts = UserDefaults.standard.integer(forKey: "security_selfdestruct_attempts")
        if selfDestructAttempts == 0 { selfDestructAttempts = 10 }
    }
}
