import EventKit
import Foundation
import WidgetKit

@MainActor
final class CalendarService: ObservableObject {
    enum AuthState {
        case unknown, denied, authorized
    }

    @Published var authState: AuthState = .unknown
    @Published var isSyncing = false
    @Published var lastSyncError: String?
    @Published var availableCalendars: [EKCalendar] = []
    @Published private(set) var selectedCalendarIDs: Set<String> = []

    private let store = EKEventStore()
    private let selectionKey = "selectedCalendarIDs"

    /// How far ahead to pull events for the "Assignments" widget.
    private let lookaheadDays = 14

    func refreshAuthState() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            authState = .authorized
            loadAvailableCalendars()
        case .denied, .restricted:
            authState = .denied
        case .notDetermined, .writeOnly:
            authState = .unknown
        @unknown default:
            authState = .unknown
        }
    }

    /// Requests access, then does an immediate sync on success. Google
    /// events show up here automatically once the Google account is added
    /// under iOS Settings → Calendar → Accounts — EventKit reads every
    /// calendar source the system knows about, not just Apple's.
    func requestAccessAndSync() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            authState = granted ? .authorized : .denied
            if granted {
                loadAvailableCalendars()
                await sync()
            }
        } catch {
            authState = .denied
            lastSyncError = error.localizedDescription
        }
    }

    /// Populates `availableCalendars` from every source EventKit knows about
    /// (iCloud, Google once added in Settings, Exchange, local, etc.) and
    /// restores the saved selection — defaulting to "all calendars" the
    /// first time, so nothing silently goes missing before the user visits
    /// the connections screen.
    private func loadAvailableCalendars() {
        availableCalendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        if let saved = AppGroup.defaults.array(forKey: selectionKey) as? [String] {
            selectedCalendarIDs = Set(saved).intersection(availableCalendars.map(\.calendarIdentifier))
        } else {
            selectedCalendarIDs = Set(availableCalendars.map(\.calendarIdentifier))
        }
    }

    func setCalendar(_ calendar: EKCalendar, included: Bool) {
        if included {
            selectedCalendarIDs.insert(calendar.calendarIdentifier)
        } else {
            selectedCalendarIDs.remove(calendar.calendarIdentifier)
        }
        AppGroup.defaults.set(Array(selectedCalendarIDs), forKey: selectionKey)
        Task { await sync() }
    }

    func sync() async {
        guard authState == .authorized else { return }
        isSyncing = true
        defer { isSyncing = false }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday),
              let endOfLookahead = calendar.date(byAdding: .day, value: lookaheadDays, to: startOfToday) else {
            return
        }

        let calendarsToQuery = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        // An empty selection means "nothing chosen yet" (e.g. before the
        // first calendar list load) — fall back to every calendar rather
        // than silently returning zero events.
        let predicate = store.predicateForEvents(
            withStart: startOfToday,
            end: endOfLookahead,
            calendars: calendarsToQuery.isEmpty ? nil : calendarsToQuery
        )
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        let dueToday = events.filter { calendar.isDate($0.startDate, inSameDayAs: startOfToday) }.count
        let dueThisWeek = events.filter { $0.startDate < endOfWeek }.count

        let upcoming = events.prefix(25).map { event in
            CalendarEventSummary(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled event",
                calendarTitle: event.calendar.title,
                startDate: event.startDate,
                isAllDay: event.isAllDay
            )
        }

        let snapshot = CalendarSnapshot(
            lastSynced: now,
            dueTodayCount: dueToday,
            dueThisWeekCount: dueThisWeek,
            upcoming: Array(upcoming)
        )
        CalendarStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
