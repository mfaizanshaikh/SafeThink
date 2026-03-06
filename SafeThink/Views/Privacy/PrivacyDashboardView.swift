import SwiftUI

struct PrivacyDashboardView: View {
    @StateObject private var viewModel = PrivacyDashboardViewModel()

    var body: some View {
        List {
            // Hero stats
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)

                    Text("\(viewModel.conversationCount) conversations, \(viewModel.messageCount) messages")
                        .font(.headline)

                    Text("All stored locally on your device")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            // Network activity
            Section("Network Activity") {
                if viewModel.hasNoNetworkActivity {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("No data has left your device")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Text("Total requests:")
                        Spacer()
                        Text("\(viewModel.totalRequests)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Data sent:")
                        Spacer()
                        Text(viewModel.totalDataSent)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.networkLogs.prefix(20)) { log in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(log.destination)
                                    .font(.subheadline)
                                    .bold()
                                Spacer()
                                Text(log.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(log.purpose)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Permissions
            Section("Permissions") {
                ForEach(viewModel.permissions) { perm in
                    HStack {
                        Image(systemName: perm.icon)
                            .frame(width: 24)
                        Text(perm.name)
                        Spacer()
                        Image(systemName: perm.isGranted ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(perm.isGranted ? .green : .secondary)
                    }
                }
            }

            // Data controls
            Section("Data Controls") {
                Button(role: .destructive) {
                    viewModel.deleteMode = .data
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Label("Delete All My Data", systemImage: "trash")
                }

                Button(role: .destructive) {
                    viewModel.deleteMode = .everything
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Label("Delete Everything Including Models", systemImage: "trash.fill")
                }
            }
        }
        .navigationTitle("Privacy")
        .onAppear { viewModel.refresh() }
        .alert("Confirm Deletion", isPresented: $viewModel.showDeleteConfirmation) {
            TextField("Type DELETE to confirm", text: $viewModel.deleteConfirmationText)
            Button("Cancel", role: .cancel) {
                viewModel.deleteConfirmationText = ""
            }
            Button("Delete", role: .destructive) {
                switch viewModel.deleteMode {
                case .data:
                    viewModel.deleteAllData()
                case .everything:
                    viewModel.deleteEverything()
                }
            }
            .disabled(viewModel.deleteConfirmationText != "DELETE")
        } message: {
            Text("This action cannot be undone. Type DELETE to confirm.")
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyDashboardView()
    }
}
