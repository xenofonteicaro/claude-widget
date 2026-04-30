import SwiftUI
import WidgetKit

struct AIUsageWidgetView: View {
    let entry: AIUsageWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  SmallView(entry: entry)
            case .systemMedium: MediumView(entry: entry)
            default:            LargeView(entry: entry)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Small (2x2): show the week-all bar — the most important long window.

private struct SmallView: View {
    let entry: AIUsageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let week = entry.limits.sevenDay, !week.isExpired() {
                Text("\(Int(week.usedPercentage.rounded()))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetThreshold.color(for: week.usedPercentage))
                    .monospacedDigit()

                MiniBar(
                    fraction: max(0, min(1, week.usedPercentage / 100)),
                    color: WidgetThreshold.color(for: week.usedPercentage)
                )
                .frame(height: 4)

                Text("Week · resets in \(WidgetCountdown.string(from: .now, to: week.resetsAt))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("—%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Awaiting CLI data")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}

// MARK: - Medium (4x2): three small columns, one per window.

private struct MediumView: View {
    let entry: AIUsageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI USAGE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                Column(label: "Session", limit: entry.limits.fiveHour)
                Column(label: "Week", limit: entry.limits.sevenDay)
                Column(label: "Sonnet", limit: entry.limits.sevenDaySonnet)
            }
        }
        .padding(12)
    }

    private struct Column: View {
        let label: String
        let limit: WidgetRateLimit?

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                if let limit, !limit.isExpired() {
                    Text("\(Int(limit.usedPercentage.rounded()))%")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetThreshold.color(for: limit.usedPercentage))
                        .monospacedDigit()

                    MiniBar(
                        fraction: max(0, min(1, limit.usedPercentage / 100)),
                        color: WidgetThreshold.color(for: limit.usedPercentage)
                    )
                    .frame(height: 3)

                    Text(WidgetCountdown.string(from: .now, to: limit.resetsAt))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    MiniBar(fraction: 0, color: .secondary).frame(height: 3)
                    Text(" ")
                        .font(.system(size: 9, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Large (4x4): full row layout — mirrors the popover.

private struct LargeView: View {
    let entry: AIUsageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI USAGE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 14) {
                Row(label: "Session — 5h",          limit: entry.limits.fiveHour)
                Row(label: "Week — all models",     limit: entry.limits.sevenDay)
                if entry.limits.sevenDaySonnet != nil {
                    Row(label: "Week — Sonnet only",limit: entry.limits.sevenDaySonnet)
                }
            }

            Spacer(minLength: 0)

            if let last = entry.lastUpdated {
                Text("Updated \(formatted(last))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
    }

    private struct Row: View {
        let label: String
        let limit: WidgetRateLimit?

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let limit, !limit.isExpired() {
                        Text("resets in \(WidgetCountdown.string(from: .now, to: limit.resetsAt))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    } else if limit != nil {
                        Text("reset · awaiting next turn")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    if let limit, !limit.isExpired() {
                        Text("\(Int(limit.usedPercentage.rounded()))%")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(WidgetThreshold.color(for: limit.usedPercentage))
                            .monospacedDigit()
                    } else {
                        Text(limit == nil ? "—" : "0%")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                MiniBar(
                    fraction: barFraction(limit),
                    color: barColor(limit)
                )
                .frame(height: 4)
            }
        }

        private func barFraction(_ limit: WidgetRateLimit?) -> Double {
            guard let limit, !limit.isExpired() else { return 0 }
            return min(1, max(0, limit.usedPercentage / 100))
        }

        private func barColor(_ limit: WidgetRateLimit?) -> Color {
            guard let limit, !limit.isExpired() else { return .secondary }
            return WidgetThreshold.color(for: limit.usedPercentage)
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Shared bar

private struct MiniBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(.quaternary)
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: max(0, proxy.size.width * fraction))
            }
        }
    }
}
