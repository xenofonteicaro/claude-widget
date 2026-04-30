import WidgetKit

struct ClaudeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClaudeWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ClaudeWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeWidgetEntry>) -> Void) {
        let now = Date.now
        let current = currentEntry()

        // Schedule a redraw at the *next* reset moment (whichever window expires
        // first), so the widget visually rolls over to "0% awaiting next turn"
        // exactly when its bar should reset. The store also kicks WidgetCenter
        // any time `latest.json` changes, so this is just the safety net.
        let nextReset = [
            current.limits.fiveHour?.resetsAt,
            current.limits.sevenDay?.resetsAt,
            current.limits.sevenDaySonnet?.resetsAt
        ]
            .compactMap { $0 }
            .filter { $0 > now }
            .min()

        var entries = [current]
        if let resetAt = nextReset {
            entries.append(ClaudeWidgetEntry(date: resetAt, limits: current.limits, lastUpdated: current.lastUpdated))
        }

        let policy: TimelineReloadPolicy = .after(nextReset ?? now.addingTimeInterval(15 * 60))
        completion(Timeline(entries: entries, policy: policy))
    }

    private func currentEntry() -> ClaudeWidgetEntry {
        let (limits, lastUpdated) = WidgetRateLimitsLoader.load()
        return ClaudeWidgetEntry(date: .now, limits: limits, lastUpdated: lastUpdated)
    }
}
