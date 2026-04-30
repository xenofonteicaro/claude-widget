import SwiftUI

/// Maps a percentage to the menu-bar / widget color used everywhere in the UI.
enum Threshold {
    static func color(for percentage: Double?) -> Color {
        guard let pct = percentage else { return .secondary }
        switch pct {
        case ..<60:   return .green
        case ..<85:   return .orange
        default:      return .red
        }
    }
}

/// Formats the time remaining until `date` as the short copy shown beside each
/// progress bar (e.g. `"2h 14m"` or `"3d 6h"`).
enum CountdownFormatter {
    static func string(from now: Date, to target: Date) -> String {
        let interval = max(0, target.timeIntervalSince(now))

        let days = Int(interval / 86_400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
