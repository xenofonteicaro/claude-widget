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
                source: .claude,
                limits: store.claudeRateLimits,
                lastUpdated: store.claudeLastUpdated
            )

            Divider()

            sourceSection(
                source: .codex,
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
    private func sourceSection(source: UsageSource, limits: RateLimits, lastUpdated: Date?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SourceBadge(source: source)
                Text(source.title)
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

private enum UsageSource {
    case claude
    case codex

    var title: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    var symbolName: String {
        switch self {
        case .claude: return "sparkles"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var foreground: Color {
        switch self {
        case .claude: return Color(red: 1.00, green: 0.45, blue: 0.30)
        case .codex: return Color(red: 0.35, green: 0.78, blue: 1.00)
        }
    }

    var background: Color {
        foreground.opacity(0.16)
    }
}

private struct SourceBadge: View {
    let source: UsageSource

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(source.background)
            Image(systemName: source.symbolName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(source.foreground)
        }
        .frame(width: 18, height: 18)
        .alignmentGuide(.firstTextBaseline) { context in
            context[VerticalAlignment.center] + 4
        }
        .accessibilityLabel(source.title)
    }
}
