import Foundation
import SwiftUI

// The Widget Extension is its own bundle and doesn't share source files
// at the target level. We re-declare the small types we need here so both
// targets stay independent and Codable formats stay aligned.

struct WidgetRateLimit: Equatable, Hashable {
    let usedPercentage: Double
    let resetsAt: Date

    func isExpired(now: Date = .init()) -> Bool {
        resetsAt <= now
    }
}

struct WidgetRateLimits: Equatable {
    let fiveHour: WidgetRateLimit?
    let sevenDay: WidgetRateLimit?
    let sevenDaySonnet: WidgetRateLimit?

    static let empty = WidgetRateLimits(fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil)
}

enum WidgetAppGroup {
    static let identifier = "group.icaro.claudewidget"

    static var latestURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)?
            .appendingPathComponent("latest.json")
    }
}

/// Forgiving decoder. Returns `.empty` for any failure path so the widget never
/// crashes on a malformed file mid-write.
enum WidgetRateLimitsLoader {
    static func load() -> (limits: WidgetRateLimits, lastUpdated: Date?) {
        guard let url = WidgetAppGroup.latestURL,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return (.empty, nil)
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modified = attrs?[.modificationDate] as? Date

        return (
            WidgetRateLimits(
                fiveHour:        decode(json["five_hour"] as? [String: Any]),
                sevenDay:        decode(json["seven_day"] as? [String: Any]),
                sevenDaySonnet:  decode(json["seven_day_sonnet"] as? [String: Any])
            ),
            modified
        )
    }

    private static func decode(_ dict: [String: Any]?) -> WidgetRateLimit? {
        guard let dict,
              let pct = (dict["used_percentage"] as? NSNumber)?.doubleValue,
              let resets = (dict["resets_at"] as? NSNumber)?.doubleValue
        else { return nil }
        return WidgetRateLimit(
            usedPercentage: pct,
            resetsAt: Date(timeIntervalSince1970: resets)
        )
    }
}

enum WidgetThreshold {
    static func color(for percentage: Double?) -> Color {
        guard let pct = percentage else { return .secondary }
        switch pct {
        case ..<60:  return .green
        case ..<85:  return .orange
        default:     return .red
        }
    }
}

enum WidgetCountdown {
    static func string(from now: Date, to target: Date) -> String {
        let interval = max(0, target.timeIntervalSince(now))
        let days = Int(interval / 86_400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
