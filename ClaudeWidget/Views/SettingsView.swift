import SwiftUI

/// Minimal Settings window: shows pipeline health and how to install the
/// statusLine capture script. No "always-on-top", no preferences UI in V1.
struct SettingsView: View {
    @ObservedObject var store: RateLimitsStore
    @StateObject private var health = CaptureHealth()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Widget")
                    .font(.title2.weight(.semibold))
                Text("Reads usage from Claude Code's statusLine pipe.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Capture script")
                    .font(.headline)

                statusRow

                Text("The widget needs a statusLine entry in `~/.claude/settings.json` "
                     + "that pipes Claude Code's per-turn JSON into this app's container. "
                     + "See the project README for the exact one-liner.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Latest data")
                    .font(.headline)
                if let url = AppGroup.latestURL {
                    Text(url.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let last = store.lastUpdated {
                    Text("Last updated \(formatted(last))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No file yet — run Claude Code once.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 340)
        .onAppear { health.refresh(store: store) }
        .onChange(of: store.lastUpdated) { _, _ in health.refresh(store: store) }
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(health.color)
                .frame(width: 10, height: 10)
            Text(health.title)
                .font(.callout.weight(.medium))
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f.string(from: date)
    }
}

@MainActor
final class CaptureHealth: ObservableObject {
    enum State { case fresh, stale, missing }

    @Published private(set) var state: State = .missing

    var title: String {
        switch state {
        case .fresh:   return "Active"
        case .stale:   return "Stale — run Claude Code to refresh"
        case .missing: return "Not configured"
        }
    }

    var color: Color {
        switch state {
        case .fresh:   return .green
        case .stale:   return .orange
        case .missing: return .red
        }
    }

    func refresh(store: RateLimitsStore) {
        guard store.fileExists, let last = store.lastUpdated else {
            state = .missing
            return
        }
        let age = Date.now.timeIntervalSince(last)
        state = age < 30 * 60 ? .fresh : .stale
    }
}
