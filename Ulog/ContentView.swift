import SwiftUI

struct ContentView: View {
    @State private var viewModel: ChatViewModel

    init(apfelService: ApfelService) {
        _viewModel = State(initialValue: ChatViewModel(apfelService: apfelService))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.messages.isEmpty {
                emptyState
            } else {
                MessageListView(messages: viewModel.messages, isGenerating: viewModel.isGenerating)
            }

            Divider()

            InputBarView(
                text: $viewModel.inputText,
                isGenerating: viewModel.isGenerating,
                isServerReady: viewModel.serverStatus == .ready,
                onSend: { viewModel.sendMessage() },
                onStop: { viewModel.stopGeneration() }
            )

            StatusIndicator(status: viewModel.serverStatus)
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await viewModel.startServer()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.clearChat() }) {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.messages.isEmpty)
                .help("Clear chat")
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
