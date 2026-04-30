import WidgetKit

struct AIUsageWidgetEntry: TimelineEntry {
    let date: Date
    let limits: WidgetRateLimits
    let lastUpdated: Date?

    static let placeholder = AIUsageWidgetEntry(
        date: .now,
        limits: WidgetRateLimits(
            fiveHour:       WidgetRateLimit(usedPercentage: 34, resetsAt: .now.addingTimeInterval(7_500)),
            sevenDay:       WidgetRateLimit(usedPercentage: 3,  resetsAt: .now.addingTimeInterval(86_400 * 5)),
            sevenDaySonnet: WidgetRateLimit(usedPercentage: 4,  resetsAt: .now.addingTimeInterval(86_400 * 5))
        ),
        lastUpdated: .now
    )
}
