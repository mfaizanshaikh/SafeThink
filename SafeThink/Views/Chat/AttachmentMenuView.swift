import SwiftUI
import PhotosUI

struct AttachmentMenuView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }

                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Document", systemImage: "doc")
                    }
                } header: {
                    Text("Attach")
                }

                Section {
                    Button {
                        viewModel.isWebSearchEnabled = true
                        dismiss()
                    } label: {
                        Label("Search Web", systemImage: "globe")
                    }
                } header: {
                    Text("Web")
                } footer: {
                    Text("Search results will be processed locally by your on-device model.")
                }
            }
            .navigationTitle("Attach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.selectedImages.append(image)
                        dismiss()
                    }
                }
            }
            .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [.pdf, .plainText, .commaSeparatedText]) { result in
                if case .success(let url) = result {
                    viewModel.attachedDocumentURL = url
                    dismiss()
                }
            }
        }
    }
}
