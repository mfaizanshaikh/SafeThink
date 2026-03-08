import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var security = SecurityService.shared
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        Form {
            // Appearance
            Section {
                Picker("Appearance", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedback)
            }

            // AI Model
            Section {
                NavigationLink {
                    ModelSettingsView(viewModel: viewModel)
                } label: {
                    HStack {
                        Label("Model Settings", systemImage: "slider.horizontal.3")
                        Spacer()
                        Text(InferenceService.shared.loadedModelId?.components(separatedBy: "/").last ?? "None")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                NavigationLink {
                    ModelManagerView()
                } label: {
                    Label("Manage Models", systemImage: "cpu")
                }
            }

            // Security
            Section {
                NavigationLink {
                    SecuritySettingsView()
                } label: {
                    HStack {
                        Label("Security", systemImage: "lock.shield")
                        Spacer()
                        if security.isBiometricEnabled {
                            Text("On")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Data
            Section {
                Button {
                    exportAllChats()
                } label: {
                    HStack {
                        Label("Export All Chats", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isExporting)

                Button(role: .destructive) {
                    viewModel.clearTarget = .chats
                    viewModel.showClearConfirmation = true
                } label: {
                    Label("Clear Chat History", systemImage: "trash")
                }

                Button(role: .destructive) {
                    viewModel.clearTarget = .allData
                    viewModel.showClearConfirmation = true
                } label: {
                    Label("Clear All Data", systemImage: "exclamationmark.triangle")
                }
            } header: {
                Text("Data")
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
        .alert("Export Error", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func exportAllChats() {
        isExporting = true
        Task {
            do {
                let url = try ExportService.shared.exportAllConversations(format: .json)
                exportURL = url
                showShareSheet = true
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
