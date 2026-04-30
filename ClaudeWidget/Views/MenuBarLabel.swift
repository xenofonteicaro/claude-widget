import SwiftUI

/// Compact text shown directly in the macOS menu bar.
///
/// Format: `"34% · 3%w"` — session percentage on the left, week-all on the right.
/// We tint the week number (the high-signal long-window one) with the threshold
/// color; the session number stays in `.secondary` so the menu-bar reads
/// session-quiet / week-loud.
///
/// IMPORTANT: `MenuBarExtra` only honors a single `Text` (or `Image`) in its
/// label; an `HStack` of multiple `Text`s gets silently truncated to the first
/// element on macOS 14+. That's why we build one concatenated `Text` here.
struct MenuBarLabel: View {
    let rateLimits: RateLimits

    var body: some View {
        sessionText
        + separator
        + weekText
    }

    // MARK: - Pieces

    private var sessionText: Text {
        Text(format(rateLimits.fiveHour?.usedPercentage))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary)
            .monospacedDigit()
    }

    private var weekText: Text {
        let pct = rateLimits.sevenDay?.usedPercentage
        return Text(format(pct) + "w")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(Threshold.color(for: pct))
            .monospacedDigit()
    }

    private var separator: Text {
        Text(" · ")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary.opacity(0.5))
    }

    private func format(_ pct: Double?) -> String {
        guard let pct else { return "—%" }
        return "\(Int(pct.rounded()))%"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        MenuBarLabel(rateLimits: .empty)
        MenuBarLabel(rateLimits: RateLimits(
            fiveHour: RateLimit(usedPercentage: 34, resetsAt: .now.addingTimeInterval(7_500)),
            sevenDay: RateLimit(usedPercentage: 3, resetsAt: .now.addingTimeInterval(600_000)),
            sevenDaySonnet: nil
        ))
        MenuBarLabel(rateLimits: RateLimits(
            fiveHour: RateLimit(usedPercentage: 72, resetsAt: .now.addingTimeInterval(7_500)),
            sevenDay: RateLimit(usedPercentage: 88, resetsAt: .now.addingTimeInterval(600_000)),
            sevenDaySonnet: nil
        ))
    }
    .padding()
}
