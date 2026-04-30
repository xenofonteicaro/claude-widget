import SwiftUI

/// One row of: label · big % · countdown · colored progress bar.
/// Used in the menu-bar popover and (subtly tweaked) in the widget.
struct RateRowView: View {
    let label: String
    let limit: RateLimit?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if let limit, !limit.isExpired(now: now) {
                    Text(CountdownFormatter.string(from: now, to: limit.resetsAt))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                } else if limit != nil {
                    Text("reset · awaiting next turn")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("no data")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                if let limit, !limit.isExpired(now: now) {
                    Text("\(Int(limit.usedPercentage.rounded()))%")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Threshold.color(for: limit.usedPercentage))
                } else if limit != nil {
                    Text("0%")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ProgressBar(
                fraction: barFraction,
                color: barColor
            )
            .frame(height: 4)
        }
    }

    private var barFraction: Double {
        guard let limit, !limit.isExpired(now: now) else { return 0 }
        return min(1, max(0, limit.usedPercentage / 100))
    }

    private var barColor: Color {
        guard let limit, !limit.isExpired(now: now) else { return .secondary }
        return Threshold.color(for: limit.usedPercentage)
    }
}

/// Lightweight progress bar — a `Capsule` track with a colored fill, no animations
/// the user didn't ask for.
struct ProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.quaternary)
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: max(0, proxy.size.width * fraction))
            }
        }
    }
}
