<p align="center">
  <img src="AppStoreAssets/AppIcon-AppStore-1024x1024.png" width="120" height="120" style="border-radius: 22px;" alt="SafeThink Icon">
</p>

<h1 align="center">SafeThink</h1>

<p align="center">
  <strong>The AI assistant that never sends your data anywhere.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/privacy-100%25%20on--device-brightgreen" alt="Privacy">
</p>

---

SafeThink is a privacy-first AI assistant for iOS that runs large language models **entirely on-device**. No cloud APIs, no telemetry, no data collection. Your conversations never leave your phone.

## Features

- **On-Device LLM Inference** — Run Qwen 3 models (0.6B / 4B / 8B) locally via llama.cpp. Streaming token generation with real-time performance stats.
- **Chat Interface** — Full ChatGPT-like experience with markdown rendering, code syntax highlighting, conversation history, search, pin & archive.
- **Document RAG** — Import PDF, TXT, DOCX, or CSV files. Documents are chunked, embedded, and retrieved with semantic search to give the model grounded answers.
- **Persistent Memory** — The assistant remembers facts across conversations using embedding-based retrieval, injected into system prompts automatically.
- **Image Editing** — Built-in image filters, brightness/contrast adjustment, background removal, and rotation — all processed on-device with Core Image.
- **Voice Input** — Hold-to-talk speech recognition using Apple's on-device SFSpeechRecognizer.
- **Web Search** — Optional DuckDuckGo search triggered explicitly by the user (`/search` command). All network activity is logged.
- **Biometric Lock** — Face ID / Touch ID protection with configurable lock timeout.
- **Privacy Dashboard** — View all network requests the app has ever made. Full transparency.
- **Export** — Export conversations as JSON, Markdown, TXT, or PDF.

## Privacy

SafeThink is built with a zero-data-collection architecture:

- All AI inference runs on Apple Silicon (CPU/GPU/ANE)
- No analytics, no crash reporting SDKs, no tracking
- Network access is **only** used for model downloads (HuggingFace) and optional user-triggered web search (DuckDuckGo)
- Every outbound request is logged and visible in the Privacy Dashboard
- Model files are excluded from iCloud backup

## Supported Devices

| Tier | Devices | RAM | Recommended Model |
|------|---------|-----|-------------------|
| Minimum | iPhone 15+ (A16) | 6 GB | Qwen3-0.6B-4bit |
| Recommended | iPhone 15 Pro, 16 | 8 GB | Qwen3-4B-4bit |
| Premium | iPhone 16 Pro/Max | 8 GB | Qwen3-4B-4bit |
| iPad | iPad Pro M1+ | 8-16 GB | Qwen3-8B-4bit |

Requires **iOS 17+** and **3-6 GB** free storage for models.

## Architecture

```
MVVM + Service Layer (SwiftUI)

SafeThinkApp
  ├── OnboardingView
  ├── LockScreenView (biometric auth)
  └── ContentView (TabBar)
        ├── Chat        — ChatView + ConversationListView
        ├── Models      — ModelManagerView (download/manage)
        ├── Privacy     — PrivacyDashboardView (network logs)
        └── Settings    — SettingsView (security, export, model config)
```

**Key Services:**

| Service | Role |
|---------|------|
| `InferenceService` | LLM loading & streaming token generation |
| `EmbeddingService` | all-MiniLM-L6-v2 text embeddings (384D) |
| `DatabaseService` | SQLite via GRDB with FTS5 full-text search |
| `ModelDownloadService` | HuggingFace model downloads with progress tracking |
| `SecurityService` | Face ID / Touch ID, lock timeout |
| `DocumentService` | PDF/TXT/DOCX/CSV extraction, chunking, RAG pipeline |
| `MemoryService` | Persistent memory with embedding-based retrieval |
| `SearchService` | DuckDuckGo web search (user-triggered only) |
| `ImageService` | Core Image filters, background removal |
| `VoiceService` | On-device speech recognition |
| `ExportService` | Multi-format chat export |
| `NetworkLogService` | Logs all outbound network requests |

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI | SwiftUI |
| LLM Inference | llama.cpp (via llama.swift) |
| Embeddings | all-MiniLM-L6-v2 (swift-embeddings) |
| Database | GRDB.swift (SQLite + FTS5) |
| Image Processing | Core Image + Vision |
| Speech | SFSpeechRecognizer (on-device) |
| Markdown | swift-markdown-ui |
| Code Highlighting | Splash |
| Build System | XcodeGen |

## Building

**Requirements:** Xcode 16+, iOS 17+ deployment target.

```bash
# Generate the Xcode project
xcodegen generate

# Build
xcodebuild -project SafeThink.xcodeproj \
  -scheme SafeThink \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run tests
xcodebuild -project SafeThink.xcodeproj \
  -scheme SafeThinkTests \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

## Project Structure

```
SafeThink/
├── App/             Entry point, ContentView, TabBar
├── Models/          Data models (Conversation, Message, ModelInfo, etc.)
├── ViewModels/      MVVM view models (Chat, ModelManager, Settings, etc.)
├── Views/
│   ├── Chat/        Chat interface, message bubbles, conversation list
│   ├── ModelManager/ Model download & management UI
│   ├── ImageEditor/  Image editing tools
│   ├── Privacy/      Privacy dashboard
│   ├── Settings/     App settings, security, model config
│   ├── Onboarding/   First-launch walkthrough
│   └── Components/   Shared UI components
├── Services/        12 service singletons (inference, DB, security, etc.)
├── Utilities/       Constants, extensions, memory monitor
└── Resources/       Assets, entitlements, system prompt
```

## License

MIT
