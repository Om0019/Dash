import SwiftUI

struct AssignmentItem: Identifiable {
    enum Severity { case critical, warning, normal }

    let id: String
    let course: String
    let title: String
    let dueText: String
    let severity: Severity
}

struct RoutineStep: Identifiable {
    let id = UUID()
    let step: Int
    let name: String
}

enum DashboardData {
    /// Craft space id used to build `craftdocs://open?spaceId=...&blockId=...`
    /// deep links from the Craft docs card.
    static let craftSpaceID = "61705c70-6e11-b7ae-350f-fbf5f0dc5630"

    /// This semester's course folders get the big icon cards on the Craft
    /// docs card; everything else (older courses, Imported Notes, etc.)
    /// collapses into the "Other Craft folders" chip row — order matters,
    /// it matches the original dashboard layout.
    static let primaryFolderOrder = [
        "AC Circuits & Intro to Power",
        "Intro to Computer Organization",
        "Introduction to VLSI",
        "Engineering Capstone I",
    ]

    // MARK: - Calendar (iOS + Google, via EventKit — see CalendarService)

    /// Live snapshot written by the app after each calendar sync. Falls back
    /// to empty/zero until the first sync runs and permission is granted.
    static var calendarSnapshot: CalendarSnapshot { CalendarStore.load() }

    static var assignments: [AssignmentItem] {
        calendarSnapshot.upcoming.map { event in
            AssignmentItem(
                id: event.id,
                course: event.calendarTitle,
                title: event.title,
                dueText: Self.dueText(for: event),
                severity: {
                    switch event.severity {
                    case .critical: return .critical
                    case .warning: return .warning
                    case .normal: return .normal
                    }
                }()
            )
        }
    }

    static let emptyAssignmentsNote = "Nothing on the calendar yet. Sync from the app, and make sure your Google account is added under iOS Settings → Calendar → Accounts so those events show up here too."

    private static func dueText(for event: CalendarEventSummary) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(event.startDate) {
            return event.isAllDay ? "Today" : event.startDate.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInTomorrow(event.startDate) { return "Tomorrow" }
        return event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    // MARK: - Skincare routine (weekly schedule — see the "Weekly Face
    // Routine Schedule" note in Craft)

    /// AM steps don't vary by day.
    static let amRoutine: [RoutineStep] = [
        RoutineStep(step: 1, name: "Cleanser"),
        RoutineStep(step: 2, name: "Caffeine eye gel"),
        RoutineStep(step: 3, name: "Moisturizer AM (SPF 30)"),
    ]

    /// PM extras beyond cleanser/moisturizer, keyed by
    /// `Calendar.current.component(.weekday, from:)` (1 = Sunday ... 7 =
    /// Saturday): Vitamin C serum lands Tue/Thu, salicylic acid lands
    /// Tue/Thu/Sat/Sun.
    private static let pmExtrasByWeekday: [Int: [String]] = [
        1: ["Salicylic acid (nose only)"],                                // Sun
        2: [],                                                            // Mon
        3: ["Vitamin C exfoliating serum", "Salicylic acid (nose only)"], // Tue
        4: [],                                                            // Wed
        5: ["Vitamin C exfoliating serum", "Salicylic acid (nose only)"], // Thu
        6: [],                                                            // Fri
        7: ["Salicylic acid (nose only)"],                                // Sat
    ]

    static var pmRoutine: [RoutineStep] {
        let weekday = Calendar.current.component(.weekday, from: .now)
        let names = ["Cleanser"] + (pmExtrasByWeekday[weekday] ?? []) + ["Moisturizer PM"]
        return names.enumerated().map { RoutineStep(step: $0.offset + 1, name: $0.element) }
    }

    // MARK: - Craft (live via CraftService — see CraftService.swift)

    /// Live snapshot written by the app after each Craft sync. Falls back to
    /// `bundledCraftSnapshot` until the first sync completes.
    static var craftSnapshot: CraftSnapshot { CraftStore.load() ?? bundledCraftSnapshot }

    static let bundledCraftSnapshot = CraftSnapshot(
        lastSynced: ISO8601DateFormatter().date(from: "2026-08-18T00:00:00Z") ?? .now,
        totalDocs: 43,
        openTasks: 0,
        folders: [
            CraftFolderSummary(id: "4a3a73b5-810b-628a-8d90-d535487a6ef9", name: "AC Circuits & Intro to Power", emoji: "⚡", colorHex: "3987E5", docCount: 0),
            CraftFolderSummary(id: "606976ef-f369-ea6d-4fe2-e0d552eede60", name: "Intro to Computer Organization", emoji: "🖥️", colorHex: "D95926", docCount: 0),
            CraftFolderSummary(id: "bc41a310-7b83-4f75-2f87-424c4a6d47c7", name: "Introduction to VLSI", emoji: "🔬", colorHex: "199E70", docCount: 0),
            CraftFolderSummary(id: "de8fbc6b-875d-1519-0288-49a40defa3f9", name: "Engineering Capstone I", emoji: "🎓", colorHex: "C98500", docCount: 0),
            CraftFolderSummary(id: "DEC00439-C91C-4DAC-AAFF-588E77833AE0", name: "EE 317", emoji: "📘", colorHex: "D55181", docCount: 2),
            CraftFolderSummary(id: "C17D1206-8384-4346-8D9A-7BF02B274D7B", name: "EE 300", emoji: "📗", colorHex: "4A8F2F", docCount: 1),
            CraftFolderSummary(id: "B08B3954-5FE0-4A0C-B0F8-88CED2ACD61D", name: "EE 240", emoji: "🧮", colorHex: "9085E9", docCount: 5),
            CraftFolderSummary(id: "f440ae75-bab0-76d9-1297-14ca68534a93", name: "EE 325", emoji: "🎚️", colorHex: "E66767", docCount: 3),
            CraftFolderSummary(id: "B51B1925-E3D4-4C87-AFB6-23E711A1F4B9", name: "Imported Notes", emoji: "🗂️", colorHex: "75746E", docCount: 6),
        ],
        recentDocs: [
            CraftDocSummary(id: "39d65322", title: "Weekly Face Routine Schedule", folder: "Unsorted", colorHex: "75746E"),
            CraftDocSummary(id: "df96614e", title: "Glute Building Routine – Planet Fitness", folder: "Unsorted", colorHex: "75746E"),
            CraftDocSummary(id: "C8656CF4", title: "Smith machine squats: 4x10–12", folder: "Unsorted", colorHex: "75746E"),
            CraftDocSummary(id: "c6f1e955", title: "EE325 Final Review — Laplace, PID Tuning", folder: "EE 325", colorHex: "E66767"),
            CraftDocSummary(id: "46079803", title: "EE325 Lab 4 – Simulink Differential Eq.", folder: "EE 325", colorHex: "E66767"),
            CraftDocSummary(id: "15a67f45", title: "Lab 3 – Pole-Zero Plots", folder: "EE 317", colorHex: "D55181"),
        ]
    )

    static var folders: [CraftFolderSummary] { craftSnapshot.folders }
    static var recentDocs: [CraftDocSummary] { craftSnapshot.recentDocs }

    // MARK: - Stat tiles

    static var stats: (dueToday: Int, dueThisWeek: Int, craftDocs: Int, openTasks: Int) {
        let cal = calendarSnapshot
        return (cal.dueTodayCount, cal.dueThisWeekCount, craftSnapshot.totalDocs, craftSnapshot.openTasks)
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    static let dashboardPage = Color(red: 10 / 255, green: 10 / 255, blue: 11 / 255)
    static let dashboardTextSecondary = Color(red: 195 / 255, green: 194 / 255, blue: 183 / 255)
    static let dashboardTextMuted = Color(red: 143 / 255, green: 142 / 255, blue: 136 / 255)
    /// Single action color for buttons and interactive accents — the same
    /// blue as `--series-1` in the web dashboard, so nothing on screen
    /// falls outside the palette.
    static let dashboardAccent = Color(hex: "3987E5")
    static let dashboardGlassBg2 = Color.white.opacity(0.035)
    static let dashboardGlassBorder = Color.white.opacity(0.09)
    static let dashboardGridline = Color.white.opacity(0.07)
    static let dashboardStatusGood = Color(hex: "0CA30C")
    static let dashboardStatusCritical = Color(hex: "E66767")
    static let dashboardStatusWarning = Color(hex: "FAB219")
}
