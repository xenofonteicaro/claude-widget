import SwiftUI

/// Compact text shown directly in the macOS menu bar.
///
/// Format: `"C 34%/3%w · X 40%/20%w"` — Claude and Codex shown independently.
///
/// IMPORTANT: `MenuBarExtra` only honors a single `Text` (or `Image`) in its
/// label; an `HStack` of multiple `Text`s gets silently truncated to the first
/// element on macOS 14+. That's why we build one concatenated `Text` here.
struct MenuBarLabel: View {
    let claude: RateLimits
    let codex: RateLimits

    var body: some View {
        if claude.hasAnyLimit || codex.hasAnyLimit {
            sourceText(prefix: "C", limits: claude)
            + separator
            + sourceText(prefix: "X", limits: codex)
        } else {
            Text("AI —%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Pieces

    private func sourceText(prefix: String, limits: RateLimits) -> Text {
        let week = limits.sevenDay?.usedPercentage
        return Text("\(prefix) \(format(limits.fiveHour?.usedPercentage))/\(format(week))w")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(week == nil ? .secondary : Threshold.color(for: week))
            .monospacedDigit()
    }

    private var separator: Text {
        Text(" · ")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary.opacity(0.5))
    }

    private func format(_ pct: Double?) -> String {
        guard let pct else { return "—" }
        return "\(Int(pct.rounded()))%"
    }
}
