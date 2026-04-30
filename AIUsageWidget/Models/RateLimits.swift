import Foundation

/// One normalized rate-limit window emitted by a CLI capture script.
struct RateLimit: Codable, Equatable, Hashable {
    let usedPercentage: Double
    let resetsAt: Date

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }

    init(usedPercentage: Double, resetsAt: Date) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.usedPercentage = try c.decode(Double.self, forKey: .usedPercentage)
        let epoch = try c.decode(Double.self, forKey: .resetsAt)
        self.resetsAt = Date(timeIntervalSince1970: epoch)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(usedPercentage, forKey: .usedPercentage)
        try c.encode(resetsAt.timeIntervalSince1970, forKey: .resetsAt)
    }

    /// `true` once the reset moment has passed; the cached `usedPercentage` is stale
    /// and the UI should render this window as awaiting the next API call.
    func isExpired(now: Date = .init()) -> Bool {
        resetsAt <= now
    }
}

/// The normalized payload extracted from Claude Code or Codex usage JSON.
/// All windows are optional because the upstream contract is permissive
/// ("Optional: ... may be absent") and `seven_day_sonnet` is plan-dependent.
struct RateLimits: Codable, Equatable {
    let fiveHour: RateLimit?
    let sevenDay: RateLimit?
    let sevenDaySonnet: RateLimit?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }

    static let empty = RateLimits(fiveHour: nil, sevenDay: nil, sevenDaySonnet: nil)

    var hasAnyLimit: Bool {
        fiveHour != nil || sevenDay != nil || sevenDaySonnet != nil
    }
}
