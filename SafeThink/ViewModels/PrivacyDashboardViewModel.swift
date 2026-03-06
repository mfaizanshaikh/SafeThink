import Foundation
import AVFoundation
import Photos
import Speech

@MainActor
final class PrivacyDashboardViewModel: ObservableObject {
    @Published var conversationCount = 0
    @Published var messageCount = 0
    @Published var networkLogs: [NetworkLog] = []
    @Published var totalRequests = 0
    @Published var totalDataSent: String = "0 bytes"
    @Published var showDeleteConfirmation = false
    @Published var deleteConfirmationText = ""
    @Published var deleteMode: DeleteMode = .data

    enum DeleteMode {
        case data
        case everything
    }

    struct PermissionStatus: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let isGranted: Bool
    }

    @Published var permissions: [PermissionStatus] = []

    private let databaseService = DatabaseService.shared
    private let networkLogService = NetworkLogService.shared

    func refresh() {
        conversationCount = (try? databaseService.conversationCount()) ?? 0
        messageCount = (try? databaseService.messageCount()) ?? 0

        networkLogService.loadLogs()
        networkLogs = networkLogService.logs
        totalRequests = networkLogService.totalRequests
        totalDataSent = networkLogService.formattedTotalData

        checkPermissions()
    }

    private func checkPermissions() {
        var perms: [PermissionStatus] = []

        // Camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        perms.append(PermissionStatus(name: "Camera", icon: "camera", isGranted: cameraStatus == .authorized))

        // Microphone
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        perms.append(PermissionStatus(name: "Microphone", icon: "mic", isGranted: micStatus == .authorized))

        // Speech Recognition
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        perms.append(PermissionStatus(name: "Speech", icon: "waveform", isGranted: speechStatus == .authorized))

        // Photos
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        perms.append(PermissionStatus(name: "Photos", icon: "photo", isGranted: photoStatus == .authorized))

        // Face ID
        perms.append(PermissionStatus(name: "Face ID", icon: "faceid",
            isGranted: SecurityService.shared.isBiometricEnabled))

        // Network (always available)
        perms.append(PermissionStatus(name: "Network", icon: "wifi", isGranted: true))

        permissions = perms
    }

    var hasNoNetworkActivity: Bool {
        networkLogs.isEmpty
    }

    func deleteAllData() {
        guard deleteConfirmationText == "DELETE" else { return }
        try? databaseService.deleteAllData()
        deleteConfirmationText = ""
        refresh()
    }

    func deleteEverything() {
        guard deleteConfirmationText == "DELETE" else { return }
        try? databaseService.deleteAllData()
        // Also delete models
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("models"))
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("documents"))
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("embeddings"))
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("exports"))
        deleteConfirmationText = ""
        refresh()
    }
}
