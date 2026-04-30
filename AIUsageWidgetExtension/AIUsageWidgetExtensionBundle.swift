import SwiftUI
import WidgetKit

@main
struct AIUsageWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        AIUsageWidget()
    }
}

struct AIUsageWidget: Widget {
    static let kind = "AIUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: AIUsageWidgetProvider()) { entry in
            AIUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("AI Usage")
        .description("Session and weekly usage from Claude Code or Codex.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
