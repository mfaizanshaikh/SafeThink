import SwiftUI

struct ModelCardView: View {
    let model: ModelInfo
    let status: ModelDownloadStatus
    let progress: Double
    let isActive: Bool
    let compatibility: ModelCompatibility
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onActivate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.headline)
                        compatibilityBadge
                    }
                    Text("\(model.parameterCount) parameters | \(model.quantization) | \(model.sizeFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Context length
            HStack {
                Label("Context: \(model.contextLength / 1024)K tokens", systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.isMultimodal {
                    Label("Vision", systemImage: "eye")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Status / Actions
            switch status {
            case .notDownloaded:
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case .downloading(let downloadProgress):
                VStack(spacing: 4) {
                    ProgressView(value: downloadProgress)
                    HStack {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                        Spacer()
                        Button("Cancel", action: onCancel)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

            case .verifying:
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Verifying checksum...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .ready:
                HStack(spacing: 12) {
                    if !isActive {
                        Button(action: onActivate) {
                            Label("Load Model", systemImage: "play.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }

            case .error(let message):
                VStack(alignment: .leading, spacing: 4) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Retry", action: onDownload)
                        .font(.caption)
                        .buttonStyle(.bordered)
                }

            case .updateAvailable:
                Button(action: onDownload) {
                    Label("Update Available", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var compatibilityBadge: some View {
        switch compatibility {
        case .compatible:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .limited:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
        case .incompatible:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}
