import Foundation

/// Shared container the app and widget extension both read/write through.
/// After enabling the "App Groups" capability on both targets in Xcode's
/// Signing & Capabilities tab, make sure the group identifier there matches
/// this string exactly.
enum AppGroup {
    static let suiteName = "group.com.orlandodash.shared"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

/// The user's personal Craft Connect link, entered once in the Connections
/// screen and stored only in the local App Group container — never hardcoded
/// in source, since it carries an account-scoped access token.
enum CraftConnectConfig {
    private static let key = "craftConnectURLString"

    static var urlString: String? {
        get { AppGroup.defaults.string(forKey: key) }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }

    static var url: URL? {
        urlString.flatMap { URL(string: $0) }
    }
}

/// When and whether the face routine / calendar / Craft data auto-refreshes
/// in the background, user-adjustable from the Connections screen (default:
/// every morning at 2am). Read by both the app (to schedule the background
/// task) and the widget extension (to target its own timeline reload at the
/// same moment, since the OS doesn't guarantee the background task runs
/// exactly on time).
enum RefreshScheduleConfig {
    private static let hourKey = "refreshHour"
    private static let minuteKey = "refreshMinute"
    private static let enabledKey = "refreshAutoEnabled"

    static var hour: Int {
        get { AppGroup.defaults.object(forKey: hourKey) as? Int ?? 2 }
        set { AppGroup.defaults.set(newValue, forKey: hourKey) }
    }

    static var minute: Int {
        get { AppGroup.defaults.object(forKey: minuteKey) as? Int ?? 0 }
        set { AppGroup.defaults.set(newValue, forKey: minuteKey) }
    }

    static var isEnabled: Bool {
        get { AppGroup.defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { AppGroup.defaults.set(newValue, forKey: enabledKey) }
    }

    /// The stored hour/minute expressed as today's `Date`, for binding to a
    /// SwiftUI `DatePicker(.hourAndMinute)` — only the time-of-day components
    /// are ever read back out of it.
    static func storedTimeToday() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    /// The next occurrence of the configured hour/minute strictly after
    /// `date` — today's if it hasn't passed yet, otherwise tomorrow's.
    static func nextRefreshDate(after date: Date = Date()) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let todayCandidate = calendar.date(from: components) ?? date
        if todayCandidate > date { return todayCandidate }
        return calendar.date(byAdding: .day, value: 1, to: todayCandidate) ?? date.addingTimeInterval(86400)
    }
}

// MARK: - Calendar snapshot (written by the app after an EventKit sync, read by the widgets)

struct CalendarEventSummary: Codable, Identifiable {
    var id: String
    var title: String
    var calendarTitle: String
    var startDate: Date
    var isAllDay: Bool

    var severity: AssignmentItem.Severity {
        let calendar = Calendar.current
        if calendar.isDateInToday(startDate) { return .critical }
        if let daysAway = calendar.dateComponents([.day], from: Date(), to: startDate).day, daysAway <= 2 {
            return .warning
        }
        return .normal
    }
}

struct CalendarSnapshot: Codable {
    var lastSynced: Date
    var dueTodayCount: Int
    var dueThisWeekCount: Int
    var upcoming: [CalendarEventSummary]

    static let empty = CalendarSnapshot(lastSynced: .distantPast, dueTodayCount: 0, dueThisWeekCount: 0, upcoming: [])
}

enum CalendarStore {
    private static let key = "calendarSnapshot"

    static func save(_ snapshot: CalendarSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    static func load() -> CalendarSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(CalendarSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

// MARK: - Craft snapshot (refreshed by asking Claude to re-sync via its Craft connection, then rebuilding)

struct CraftFolderSummary: Codable, Identifiable {
    var id: String
    var name: String
    var emoji: String
    var colorHex: String
    var docCount: Int
}

struct CraftDocSummary: Codable, Identifiable {
    var id: String
    var title: String
    var folder: String
    var colorHex: String
}

struct CraftSnapshot: Codable {
    var lastSynced: Date
    var totalDocs: Int
    var openTasks: Int
    var folders: [CraftFolderSummary]
    var recentDocs: [CraftDocSummary]
}

enum CraftStore {
    private static let key = "craftSnapshot"

    static func save(_ snapshot: CraftSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    /// Returns the last live sync, or nil if the app has never synced yet
    /// (widgets should fall back to `DashboardData.bundledCraftSnapshot`).
    static func load() -> CraftSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CraftSnapshot.self, from: data)
    }
}
