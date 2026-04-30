import SwiftUI
import AppKit

@main
struct ClaudeWidgetApp: App {
    @StateObject private var store = RateLimitsStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                store: store,
                openSettings: openSettings,
                quit: { NSApplication.shared.terminate(nil) }
            )
        } label: {
            MenuBarLabel(rateLimits: store.rateLimits)
        }
        .menuBarExtraStyle(.window)

        Window("Claude Widget", id: "settings") {
            SettingsView(store: store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 340)
    }

    /// `LSUIElement` apps don't activate themselves when a window opens, so the
    /// Settings window opens behind everything (or stays hidden). Force the
    /// activation, *then* open the window — the order matters: activating after
    /// the open call leaves focus on whatever app was previously frontmost.
    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}
