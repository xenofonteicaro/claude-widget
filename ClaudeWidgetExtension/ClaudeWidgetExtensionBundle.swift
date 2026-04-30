import SwiftUI
import WidgetKit

@main
struct ClaudeWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        ClaudeWidget()
    }
}

struct ClaudeWidget: Widget {
    static let kind = "ClaudeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ClaudeWidgetProvider()) { entry in
            ClaudeWidgetView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Session and weekly usage from Claude Code's statusLine pipe.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
