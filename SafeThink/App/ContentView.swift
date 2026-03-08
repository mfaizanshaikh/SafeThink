import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case conversations = "Conversations"
    case chat = "Chat"
    case models = "Models"
    case privacy = "Privacy"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .conversations: "text.bubble"
        case .chat: "bubble.left.and.bubble.right"
        case .models: "cpu"
        case .privacy: "lock.shield"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var selectedItem: SidebarItem? = .chat
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("SafeThink")
        } detail: {
            switch selectedItem {
            case .conversations:
                NavigationStack {
                    ConversationListView(viewModel: chatViewModel) {
                        selectedItem = .chat
                    }
                }
            case .chat:
                NavigationStack {
                    ChatView(viewModel: chatViewModel, onShowSidebar: {
                        columnVisibility = .all
                    }) { selectedItem = .models }
                }
            case .models:
                NavigationStack { ModelManagerView() }
            case .privacy:
                NavigationStack { PrivacyDashboardView() }
            case .settings:
                NavigationStack { SettingsView() }
            case nil:
                NavigationStack {
                    ChatView(viewModel: chatViewModel, onShowSidebar: {
                        columnVisibility = .all
                    }) { selectedItem = .models }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
