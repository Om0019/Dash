import BackgroundTasks
import Foundation
import WidgetKit

/// Drives the daily auto-refresh of Calendar + Craft data — which the face
/// routine and the home screen widgets are built from — at the
/// user-adjustable time configured in Settings (`RefreshScheduleConfig`,
/// default 2am).
///
/// iOS only *permits* a `BGAppRefreshTask` to run at or after
/// `earliestBeginDate`; it does not guarantee the exact minute, so
/// `scheduleNext()` is called both from the app-refresh handler (to queue
/// tomorrow's run) and opportunistically whenever the app is foregrounded or
/// backgrounded, so a request is always outstanding even if a scheduled run
/// gets skipped by the system.
enum BackgroundRefreshService {
    static let taskIdentifier = "com.orlandodash.refresh"

    static func scheduleNext() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        guard RefreshScheduleConfig.isEnabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = RefreshScheduleConfig.nextRefreshDate()
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Runs the same sync the app does in the foreground, then pushes the
    /// result to the widgets. Builds its own service instances since this
    /// runs outside `ContentView`'s lifetime.
    @MainActor
    static func run() async {
        let calendarService = CalendarService()
        calendarService.refreshAuthState()
        let craftService = CraftService()

        async let calendarSync: Void = calendarService.authState == .authorized ? calendarService.sync() : ()
        async let craftSync: Void = craftService.sync()
        _ = await (calendarSync, craftSync)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
