import Foundation

/// Single source of truth for paths the app and its Widget Extension share.
enum AppGroup {
    static let identifier = "group.icaro.aiusagewidget"

    /// Container directory for the App Group; `nil` only when the entitlement is missing.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Path of the JSON the capture script writes.
    static var latestURL: URL? {
        containerURL?.appendingPathComponent("latest.json")
    }

    static var claudeURL: URL? {
        containerURL?.appendingPathComponent("claude.json")
    }

    static var codexURL: URL? {
        containerURL?.appendingPathComponent("codex.json")
    }
}
