import SwiftUI

/// Content that appears when the user clicks the menu-bar item.
/// Three rows (Session / Week all / Week Sonnet) with bars and countdowns,
/// plus a footer with last-update time and shortcuts.
struct PopoverView: View {
    @ObservedObject var store: RateLimitsStore
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            sourceSection(
                title: "Claude",
                limits: store.claudeRateLimits,
                lastUpdated: store.claudeLastUpdated
            )

            Divider()

            sourceSection(
                title: "Codex",
                limits: store.codexRateLimits,
                lastUpdated: store.codexLastUpdated
            )

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("AI Usage")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if !store.fileExists {
                Text("not configured")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let last = store.lastUpdated {
                Text("Updated \(timeFormatter.string(from: last))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Awaiting first turn")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Settings", action: openSettings)
                .buttonStyle(.borderless)
                .font(.system(size: 11))

            Button("Quit", action: quit)
                .buttonStyle(.borderless)
                .font(.system(size: 11))
        }
    }

    @ViewBuilder
    private func sourceSection(title: String, limits: RateLimits, lastUpdated: Date?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let lastUpdated {
                    Text(timeFormatter.string(from: lastUpdated))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("waiting")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(spacing: 10) {
                RateRowView(
                    label: "Session (5h)",
                    limit: limits.fiveHour,
                    now: store.now
                )
                RateRowView(
                    label: "Week - all models",
                    limit: limits.sevenDay,
                    now: store.now
                )
                if limits.sevenDaySonnet != nil {
                    RateRowView(
                        label: "Week - Sonnet only",
                        limit: limits.sevenDaySonnet,
                        now: store.now
                    )
                }
            }
        }
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }
}
