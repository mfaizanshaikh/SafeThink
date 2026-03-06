import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var security = SecurityService.shared

    var body: some View {
        Form {
            // General
            Section("General") {
                Picker("Theme", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedback)
            }

            // AI Model
            Section("AI Model") {
                NavigationLink("Model Settings") {
                    ModelSettingsView(viewModel: viewModel)
                }
                HStack {
                    Text("Active Model")
                    Spacer()
                    Text(InferenceService.shared.loadedModelId ?? "None")
                        .foregroundStyle(.secondary)
                }
            }

            // Voice
            Section("Voice") {
                Picker("Input Mode", selection: $viewModel.voiceInputMode) {
                    ForEach(VoiceInputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                if viewModel.voiceInputMode == .autoStop {
                    HStack {
                        Text("Auto-stop delay")
                        Spacer()
                        Text("\(viewModel.autoStopDuration, specifier: "%.1f")s")
                    }
                    Slider(value: $viewModel.autoStopDuration, in: 1...5, step: 0.5)
                }
            }

            // Security
            Section("Security") {
                NavigationLink("Security Settings") {
                    SecuritySettingsView()
                }
                HStack {
                    Text(security.biometricType)
                    Spacer()
                    Text(security.isBiometricEnabled ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("PIN Lock")
                    Spacer()
                    Text(security.isPINEnabled ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
            }

            // Data & Privacy
            Section("Data & Privacy") {
                Button("Export All Chats") {
                    viewModel.showExportSheet = true
                }
                Button("Clear Chat History", role: .destructive) {
                    viewModel.clearTarget = .chats
                    viewModel.showClearConfirmation = true
                }
                Button("Clear Documents", role: .destructive) {
                    viewModel.clearTarget = .documents
                    viewModel.showClearConfirmation = true
                }
                Button("Clear Memories", role: .destructive) {
                    viewModel.clearTarget = .memories
                    viewModel.showClearConfirmation = true
                }
            }

            // Storage
            Section("Storage") {
                ForEach(viewModel.storageBreakdown, id: \.0) { item in
                    HStack {
                        Text(item.0)
                        Spacer()
                        Text(item.1)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink("Manage Models") {
                    ModelManagerView()
                }
            }

            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                NavigationLink("Privacy Policy") {
                    ScrollView {
                        Text("""
                        SafeThink Privacy Policy

                        SafeThink does not collect, store, or transmit any personal data to external servers.

                        All AI processing happens locally on your device. Your conversations, documents, and personal data never leave your device.

                        Network access is only used for:
                        - Downloading AI models from HuggingFace (user-initiated)
                        - Optional web search via DuckDuckGo (user-initiated only)

                        All network activity is logged and visible in the Privacy Dashboard.

                        No analytics, no tracking, no crash reporting SDKs.
                        """)
                        .padding()
                    }
                    .navigationTitle("Privacy Policy")
                }
                NavigationLink("Open Source Licenses") {
                    ScrollView {
                        Text("""
                        SafeThink uses the following open source libraries:

                        - MLX Swift (MIT License)
                        - GRDB.swift (MIT License)
                        - swift-markdown-ui (MIT License)
                        - Splash (MIT License)
                        - swift-embeddings (MIT License)
                        """)
                        .padding()
                    }
                    .navigationTitle("Licenses")
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: viewModel.theme) { _, _ in viewModel.saveSettings() }
        .onChange(of: viewModel.hapticFeedback) { _, _ in viewModel.saveSettings() }
        .alert("Clear Data?", isPresented: $viewModel.showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearData(target: viewModel.clearTarget)
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
