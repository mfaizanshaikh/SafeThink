import SwiftUI

struct ImageEditorView: View {
    @State var originalImage: UIImage
    @State private var editedImage: UIImage?
    @State private var selectedFilter: ImageFilter = .none
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1.0
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    private let imageService = ImageService.shared

    enum ImageFilter: String, CaseIterable {
        case none = "Original"
        case sepia = "Sepia"
        case mono = "B&W"
        case vivid = "Vivid"
        case blur = "Blur"
        case autoEnhance = "Auto"
    }

    var displayImage: UIImage {
        editedImage ?? originalImage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Image preview
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                Divider()

                // Filter picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ImageFilter.allCases, id: \.self) { filter in
                            Button {
                                applyFilter(filter)
                            } label: {
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedFilter == filter ? Color.accentColor : Color(.systemGray5))
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Image(uiImage: originalImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 56, height: 56)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                    Text(filter.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(selectedFilter == filter ? Color.accentColor : Color.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                // Brightness / Contrast sliders
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "sun.min")
                        Slider(value: $brightness, in: -0.5...0.5, step: 0.05)
                            .onChange(of: brightness) { _, _ in
                                applyAdjustments()
                            }
                        Image(systemName: "sun.max")
                    }
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                        Slider(value: $contrast, in: 0.5...2.0, step: 0.1)
                            .onChange(of: contrast) { _, _ in
                                applyAdjustments()
                            }
                        Image(systemName: "circle.righthalf.filled")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)

                // Action chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ActionChip(title: "Remove Background", icon: "person.crop.rectangle") {
                            Task {
                                editedImage = try? await imageService.removeBackground(displayImage)
                            }
                        }
                        ActionChip(title: "Rotate 90", icon: "rotate.right") {
                            editedImage = imageService.rotate(displayImage, degrees: 90)
                        }
                        ActionChip(title: "Reset", icon: "arrow.uturn.backward") {
                            editedImage = nil
                            selectedFilter = .none
                            brightness = 0
                            contrast = 1.0
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)
            }
            .navigationTitle("Edit Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            UIImageWriteToSavedPhotosAlbum(displayImage, nil, nil, nil)
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            UIPasteboard.general.image = displayImage
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Text("Export")
                            .bold()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [displayImage])
            }
        }
    }

    private func applyFilter(_ filter: ImageFilter) {
        selectedFilter = filter
        switch filter {
        case .none:
            editedImage = nil
        case .sepia:
            editedImage = imageService.applySepia(originalImage)
        case .mono:
            editedImage = imageService.applyMonochrome(originalImage)
        case .vivid:
            editedImage = imageService.applyVivid(originalImage)
        case .blur:
            editedImage = imageService.applyBlur(originalImage, radius: 10)
        case .autoEnhance:
            editedImage = imageService.autoEnhance(originalImage)
        }
    }

    private func applyAdjustments() {
        let base = editedImage ?? originalImage
        editedImage = imageService.adjustBrightnessContrast(base, brightness: brightness, contrast: contrast)
    }
}

struct ActionChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
