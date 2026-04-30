import Foundation
import Combine
import WidgetKit

/// Reads `latest.json` from the App Group, exposes the parsed `RateLimits` to SwiftUI,
/// and notifies the Widget Extension to reload whenever the file changes.
///
/// Two refresh paths:
/// 1. **File watch** — a `DispatchSource` on the container directory triggers a reload
///    instantly whenever a Claude or Codex capture script rewrites `latest.json`.
/// 2. **Tick timer** — every minute we publish a fresh `now` so countdowns and
///    expired-window UI update without re-reading the file.
@MainActor
final class RateLimitsStore: ObservableObject {
    @Published private(set) var rateLimits: RateLimits = .empty
    @Published private(set) var claudeRateLimits: RateLimits = .empty
    @Published private(set) var codexRateLimits: RateLimits = .empty
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var claudeLastUpdated: Date?
    @Published private(set) var codexLastUpdated: Date?
    @Published private(set) var fileExists: Bool = false
    /// Republished every ~60s purely so views observing it can recompute countdowns.
    @Published private(set) var now: Date = .init()

    private var dirMonitor: DispatchSourceFileSystemObject?
    private var tickTimer: Timer?

    init() {
        reload()
        startTicking()
        startWatching()
    }

    deinit {
        tickTimer?.invalidate()
        // Cancellation triggers the cancel handler, which closes the FD.
        dirMonitor?.cancel()
    }

    // MARK: - Reload

    func reload() {
        let latest = load(AppGroup.latestURL)
        let claude = load(AppGroup.claudeURL)
        let codex = load(AppGroup.codexURL)

        rateLimits = latest?.limits ?? claude?.limits ?? codex?.limits ?? .empty
        claudeRateLimits = claude?.limits ?? .empty
        codexRateLimits = codex?.limits ?? .empty

        lastUpdated = [latest?.modified, claude?.modified, codex?.modified].compactMap { $0 }.max()
        claudeLastUpdated = claude?.modified
        codexLastUpdated = codex?.modified
        fileExists = latest != nil || claude != nil || codex != nil

        WidgetCenter.shared.reloadTimelines(ofKind: AIUsageWidgetKind.id)
    }

    private func load(_ url: URL?) -> (limits: RateLimits, modified: Date)? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        let parsed = (try? decoder.decode(RateLimits.self, from: data)) ?? .empty
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modified = (attrs?[.modificationDate] as? Date) ?? .init()

        return (parsed, modified)
    }

    // MARK: - Watching

    /// Watch the App Group directory for any change to `latest.json`.
    /// We watch the directory rather than the file itself so atomic-rename writes
    /// (`mv tmp final`) keep the watcher alive — replacing the inode would otherwise
    /// silently kill an FD-based watch.
    private func startWatching() {
        guard let containerURL = AppGroup.containerURL else { return }

        try? FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )

        let dirFD = open(containerURL.path, O_EVTONLY)
        guard dirFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD,
            eventMask: [.write, .extend, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.reload()
        }

        source.setCancelHandler { [dirFD] in
            close(dirFD)
        }

        source.resume()
        self.dirMonitor = source
    }

    // MARK: - Tick

    private func startTicking() {
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = .init()
            }
        }
        timer.tolerance = 5
        self.tickTimer = timer
    }
}

/// Stable identifier the app uses to talk to the widget.
enum AIUsageWidgetKind {
    static let id = "AIUsageWidget"
}
