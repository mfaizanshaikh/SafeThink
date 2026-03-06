import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(0)

            NavigationStack {
                ModelManagerView()
            }
            .tabItem {
                Label("Models", systemImage: "cpu")
            }
            .tag(1)

            NavigationStack {
                PrivacyDashboardView()
            }
            .tabItem {
                Label("Privacy", systemImage: "lock.shield")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
