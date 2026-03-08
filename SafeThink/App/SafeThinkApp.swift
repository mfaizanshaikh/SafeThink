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

    private func loadLastActiveModel() async {
        guard !inferenceService.isModelLoaded,
              let lastModelId = UserDefaults.standard.string(forKey: "lastActiveModelId"),
              let model = ModelInfo.registry.first(where: { $0.id == lastModelId }),
              ModelDownloadService.shared.isModelDownloaded(model.id) else { return }

        let fileURL = ModelDownloadService.shared.modelFileURL(for: model)
        try? await inferenceService.loadModel(from: fileURL)
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
            .task {
                await loadLastActiveModel()
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
