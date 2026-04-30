import Foundation

/// Single source of truth for paths the app and its Widget Extension share.
enum AppGroup {
    static let identifier = "group.icaro.claudewidget"

    /// Container directory for the App Group; `nil` only when the entitlement is missing.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Path of the JSON the statusLine capture script writes.
    static var latestURL: URL? {
        containerURL?.appendingPathComponent("latest.json")
    }
}
