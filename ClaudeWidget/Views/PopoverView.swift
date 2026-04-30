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

            VStack(spacing: 14) {
                RateRowView(
                    label: "Session (5h)",
                    limit: store.rateLimits.fiveHour,
                    now: store.now
                )
                RateRowView(
                    label: "Week — all models",
                    limit: store.rateLimits.sevenDay,
                    now: store.now
                )
                if store.rateLimits.sevenDaySonnet != nil {
                    RateRowView(
                        label: "Week — Sonnet only",
                        limit: store.rateLimits.sevenDaySonnet,
                        now: store.now
                    )
                }
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Claude Usage")
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

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }
}

#Preview {
    PopoverView(
        store: {
            let s = RateLimitsStore()
            return s
        }(),
        openSettings: {},
        quit: {}
    )
}
