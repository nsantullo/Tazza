import Foundation

/// Keeps a tiny local log of how many seconds Tazza kept the Mac awake each day.
/// Data never leaves the machine: it lives in UserDefaults and nothing is sent anywhere.
enum UsageLog {
    private static let key = "usageLogSeconds"

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func load() -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
    }

    /// Adds finished session time to the day the session ended.
    static func add(seconds: TimeInterval, on date: Date = Date()) {
        guard seconds > 0 else { return }
        var log = load()
        log[dayFormatter.string(from: date), default: 0] += seconds
        // Keep only the most recent 60 days so the log stays tiny.
        if log.count > 60 {
            for oldKey in log.keys.sorted().dropLast(60) { log[oldKey] = nil }
        }
        UserDefaults.standard.set(log, forKey: key)
    }

    /// Total seconds over the last `days` days (today included), plus the live session if any.
    static func total(lastDays days: Int, liveSession: TimeInterval) -> TimeInterval {
        let log = load()
        var sum: TimeInterval = liveSession
        let calendar = Calendar.current
        for offset in 0..<days {
            if let day = calendar.date(byAdding: .day, value: -offset, to: Date()) {
                sum += log[dayFormatter.string(from: day)] ?? 0
            }
        }
        return sum
    }
}
