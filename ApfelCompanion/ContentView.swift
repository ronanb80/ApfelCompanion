import SwiftUI

struct ContentView: View {
    @State private var viewModel: ChatViewModel
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all

    init(apfelService: ApfelService) {
        _viewModel = State(initialValue: ChatViewModel(apfelService: apfelService))
    }

    init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        return NavigationSplitView(columnVisibility: $sidebarVisibility) {
            List(selection: $bindableViewModel.selectedChatID) {
                ForEach(viewModel.chats) { chat in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chat.displayTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(chat.previewText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                    .tag(chat.id)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("chat.session.\(chat.id.uuidString)")
                }
                .onDelete { offsets in
                    viewModel.deleteChats(at: offsets)
                }
            }
            .navigationTitle("Chats")
            .accessibilityIdentifier("chat.sidebar")
        } detail: {
            VStack(spacing: 0) {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    MessageListView(messages: viewModel.messages, isGenerating: viewModel.isGenerating)
                }

                Divider()

                InputBarView(
                    text: $bindableViewModel.inputText,
                    isGenerating: viewModel.isGenerating,
                    isServerReady: viewModel.serverStatus == .ready,
                    onSend: { viewModel.sendMessage() },
                    onStop: { viewModel.stopGeneration() }
                )

                StatusIndicator(status: viewModel.serverStatus)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .accessibilityIdentifier("chat.root")
        .task {
            await viewModel.startServer()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(
                    action: { viewModel.createChat() },
                    label: { Image(systemName: "square.and.pencil") }
                )
                .help("New chat")
                .accessibilityLabel("New Chat")
                .accessibilityIdentifier("chat.new")
            }

            ToolbarItem(placement: .primaryAction) {
                Button(
                    action: { viewModel.trashSelectedChat() },
                    label: { Image(systemName: "trash") }
                )
                .disabled(!viewModel.canTrashSelectedChat)
                .help(viewModel.canDeleteChats ? "Delete selected chat" : "Clear chat")
                .accessibilityLabel("Delete Chat")
                .accessibilityIdentifier("chat.clear")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "message")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Start a conversation")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("chat.emptyStateTitle")
            if viewModel.serverStatus == .starting {
                ProgressView()
                    .controlSize(.small)
                Text("Starting apfel...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if case .error(let msg) = viewModel.serverStatus {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
