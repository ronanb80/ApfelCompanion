import SwiftUI

struct StatusIndicator: View {
    let status: ApfelService.Status

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch status {
        case .stopped: .gray
        case .starting: .orange
        case .ready: .green
        case .error: .red
        }
    }

    private var statusText: String {
        switch status {
        case .stopped: "Disconnected"
        case .starting: "Starting apfel..."
        case .ready: "apfel connected"
        case .error(let msg): "Error: \(msg)"
        }
    }
}
