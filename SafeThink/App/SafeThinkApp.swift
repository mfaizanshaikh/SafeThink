import SwiftUI

@main
struct SafeThinkApp: App {
    @StateObject private var securityService = SecurityService.shared
    @StateObject private var inferenceService = InferenceService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("theme") private var themeRaw: String = AppTheme.system.rawValue
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
                } else if securityService.isBiometricEnabled && !securityService.isAuthenticated {
                    LockScreenView()
                } else {
                    ContentView()
                }
            }
            .task {
                await loadLastActiveModel()
            }
            .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    securityService.checkLockState()
                }
            }
        }
    }
}
