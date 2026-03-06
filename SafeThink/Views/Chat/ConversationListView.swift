import SwiftUI

struct ConversationListView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var filter: ConversationFilter = .all

    enum ConversationFilter: String, CaseIterable {
        case all = "All"
        case pinned = "Pinned"
        case archived = "Archived"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search conversations...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .onChange(of: viewModel.searchQuery) { _, _ in
                            viewModel.searchMessages()
                        }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                // Filter
                Picker("Filter", selection: $filter) {
                    ForEach(ConversationFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Conversations list
                List {
                    if !viewModel.searchQuery.isEmpty {
                        Section("Search Results") {
                            ForEach(viewModel.searchResults) { message in
                                VStack(alignment: .leading) {
                                    Text(message.content)
                                        .lineLimit(2)
                                        .font(.subheadline)
                                    Text(message.createdAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        conversationSections
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }

    @ViewBuilder
    private var conversationSections: some View {
        let filtered = filteredConversations

        if !viewModel.pinnedConversations.isEmpty && filter != .archived {
            Section("Pinned") {
                ForEach(viewModel.pinnedConversations) { conv in
                    conversationRow(conv)
                }
            }
        }

        if filter == .all {
            if !viewModel.todayConversations.isEmpty {
                Section("Today") {
                    ForEach(viewModel.todayConversations) { conv in
                        conversationRow(conv)
                    }
                }
            }
            if !viewModel.yesterdayConversations.isEmpty {
                Section("Yesterday") {
                    ForEach(viewModel.yesterdayConversations) { conv in
                        conversationRow(conv)
                    }
                }
            }
            if !viewModel.thisWeekConversations.isEmpty {
                Section("This Week") {
                    ForEach(viewModel.thisWeekConversations) { conv in
                        conversationRow(conv)
                    }
                }
            }
            if !viewModel.olderConversations.isEmpty {
                Section("Older") {
                    ForEach(viewModel.olderConversations) { conv in
                        conversationRow(conv)
                    }
                }
            }
        }

        if filter == .archived {
            let archived = viewModel.conversations.filter { $0.isArchived }
            if archived.isEmpty {
                ContentUnavailableView("No Archived Chats", systemImage: "archivebox")
            } else {
                ForEach(archived) { conv in
                    conversationRow(conv)
                }
            }
        }

        if filtered.isEmpty && filter == .all {
            ContentUnavailableView("No Conversations", systemImage: "bubble.left.and.bubble.right",
                description: Text("Start a new conversation to get going"))
        }
    }

    private var filteredConversations: [Conversation] {
        switch filter {
        case .all: return viewModel.conversations.filter { !$0.isArchived }
        case .pinned: return viewModel.pinnedConversations
        case .archived: return viewModel.conversations.filter { $0.isArchived }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            viewModel.selectConversation(conversation)
            isPresented = false
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(conversation.title)
                        .lineLimit(1)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                Text("\(conversation.messageCount) messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                viewModel.togglePin(conversation)
            } label: {
                Label(conversation.isPinned ? "Unpin" : "Pin",
                      systemImage: conversation.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)

            Button {
                viewModel.toggleArchive(conversation)
            } label: {
                Label(conversation.isArchived ? "Unarchive" : "Archive",
                      systemImage: conversation.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            .tint(.purple)
        }
    }
}
