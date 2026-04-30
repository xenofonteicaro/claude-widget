import Foundation
import Combine
import WidgetKit

/// Reads `latest.json` from the App Group, exposes the parsed `RateLimits` to SwiftUI,
/// and notifies the Widget Extension to reload whenever the file changes.
///
/// Two refresh paths:
/// 1. **File watch** — a `DispatchSource` on the container directory triggers a reload
///    instantly whenever Claude Code's statusLine pipe rewrites `latest.json`.
/// 2. **Tick timer** — every minute we publish a fresh `now` so countdowns and
///    expired-window UI update without re-reading the file.
@MainActor
final class RateLimitsStore: ObservableObject {
    @Published private(set) var rateLimits: RateLimits = .empty
    @Published private(set) var lastUpdated: Date?
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
        guard let url = AppGroup.latestURL else {
            fileExists = false
            rateLimits = .empty
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            fileExists = false
            rateLimits = .empty
            return
        }

        fileExists = true

        // The capture script writes `{}` when `rate_limits` is absent (e.g. before
        // the first API response). Decode permissively.
        let decoder = JSONDecoder()
        if let parsed = try? decoder.decode(RateLimits.self, from: data) {
            rateLimits = parsed
        } else {
            rateLimits = .empty
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date {
            lastUpdated = modified
        } else {
            lastUpdated = .init()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: ClaudeWidgetKind.id)
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
enum ClaudeWidgetKind {
    static let id = "ClaudeWidget"
}
