import SwiftUI

struct ModelSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Generation") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text("\(viewModel.temperature, specifier: "%.2f")")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $viewModel.temperature, in: 0...2, step: 0.05)
                    Text("Lower = more focused, Higher = more creative")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Top-P")
                        Spacer()
                        Text("\(viewModel.topP, specifier: "%.2f")")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $viewModel.topP, in: 0...1, step: 0.05)
                }

                Picker("Context Window", selection: $viewModel.contextWindowLimit) {
                    Text("2K").tag(2048)
                    Text("4K").tag(4096)
                    Text("8K").tag(8192)
                    Text("16K").tag(16384)
                    Text("32K").tag(32768)
                }

                Picker("Response Format", selection: $viewModel.responseFormat) {
                    ForEach(ResponseFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }

                Toggle("Show Tokens/sec", isOn: $viewModel.showTokensPerSec)
            }

            Section("System Prompt") {
                TextEditor(text: $viewModel.systemPrompt)
                    .frame(minHeight: 120)

                Button("Reset to Default") {
                    viewModel.systemPrompt = "You are SafeThink, a helpful, accurate, and privacy-focused AI assistant running entirely on the user's device."
                }
            }
        }
        .navigationTitle("Model Settings")
        .onDisappear { viewModel.saveSettings() }
    }
}
