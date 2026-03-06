import SwiftUI

@main
struct SafeThinkApp: App {
    @StateObject private var securityService = SecurityService.shared
    @StateObject private var inferenceService = InferenceService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        try? DatabaseService.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else if (securityService.isBiometricEnabled || securityService.isPINEnabled)
                            && !securityService.isAuthenticated {
                    LockScreenView()
                } else {
                    ContentView()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    securityService.checkLockState()
                case .active:
                    securityService.checkLockState()
                default:
                    break
                }
            }
        }
    }
}
