import SwiftUI

@main
struct DashApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .backgroundTask(.appRefresh(BackgroundRefreshService.taskIdentifier)) {
            await BackgroundRefreshService.run()
            // Queue tomorrow's run — a BGAppRefreshTask only covers one shot.
            BackgroundRefreshService.scheduleNext()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefreshService.scheduleNext()
            }
        }
    }
}
