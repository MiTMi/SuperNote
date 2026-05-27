import SwiftUI

struct CloudSyncStatusView: View {
    @Bindable var monitor: CloudSyncMonitor
    @State private var rotation: Double = 0

    var body: some View {
        if case .disabled = monitor.state {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                icon
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14, height: 14)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.35))
            .help(tooltip)
            .accessibilityLabel("iCloud sync status: \(label)")
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch monitor.state {
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
                .onDisappear { rotation = 0 }
        case .idle:
            Image(systemName: "checkmark.icloud")
        case .error:
            Image(systemName: "exclamationmark.icloud")
        case .unavailable:
            Image(systemName: "icloud.slash")
        case .disabled:
            EmptyView()
        }
    }

    private var tint: Color {
        switch monitor.state {
        case .syncing: return .accentColor
        case .idle: return .secondary
        case .error: return .orange
        case .unavailable: return .secondary
        case .disabled: return .secondary
        }
    }

    private var label: String {
        switch monitor.state {
        case .syncing: return "Syncing…"
        case .idle:
            if let date = monitor.lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Synced \(formatter.localizedString(for: date, relativeTo: .now))"
            }
            return "iCloud ready"
        case .error: return "Sync error"
        case .unavailable(let reason): return reason
        case .disabled: return ""
        }
    }

    private var tooltip: String {
        switch monitor.state {
        case .syncing: return "SuperNote is syncing with iCloud"
        case .idle:
            if let date = monitor.lastSyncDate {
                return "Last sync at \(date.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Connected to iCloud"
        case .error(let message): return "Sync error — \(message)"
        case .unavailable(let reason): return reason
        case .disabled: return ""
        }
    }
}
