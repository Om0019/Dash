import WidgetKit
import SwiftUI

struct DashboardEntry: TimelineEntry {
    let date: Date
}

struct DashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
        completion(DashboardEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        let now = Date()
        // Targets the same user-configured time the app's background task
        // refreshes at (default 2am, see RefreshScheduleConfig) rather than
        // a flat "+1 day from whenever this happened to render" — the app's
        // BGAppRefreshTask is the primary driver (it can push fresh data via
        // WidgetCenter.reloadAllTimelines() while this widget is dormant),
        // this timeline policy is the fallback in case that task gets
        // skipped by the system.
        let nextRefresh = RefreshScheduleConfig.nextRefreshDate(after: now)
        let timeline = Timeline(entries: [DashboardEntry(date: now)], policy: .after(nextRefresh))
        completion(timeline)
    }
}

extension View {
    /// The app's own glass surface, rendered as a widget background: the
    /// blurred wallpaper underneath, tinted by the same palette glow the
    /// dashboard uses, so a widget looks like a piece of the app rather
    /// than a neutral frosted rectangle.
    ///
    /// Widgets **cannot** be pinned to a color scheme —
    /// `UIUserInterfaceStyle` on the extension does nothing, the app's own
    /// setting doesn't reach the extension, and
    /// `.environment(\.colorScheme, .dark)` is reapplied by WidgetKit at
    /// render time (all three verified on device). Rather than adapt to an
    /// appearance we can't control, the tint layer makes this surface
    /// deterministically dark in *either* appearance, which is why the
    /// text below can safely stay light. An earlier attempt used a flat
    /// gray scrim and looked like mud — neutral over neutral. The color is
    /// what makes it read as glass instead of dirt.
    ///
    /// Liquid Glass on widgets is a **Home Screen appearance mode**, not
    /// something the app switches on. On iOS 26, long-press the Home
    /// Screen → Edit → Customize → **Clear**, and the system strips this
    /// background and renders the widget as real Liquid Glass, refracting
    /// the wallpaper. That works because `containerBackgroundRemovable`
    /// defaults to true — the one thing the widget must not do is opt out
    /// of it.
    ///
    /// Two things were tried and don't work, so don't reach for them
    /// again: `.glassEffect(...)` inside `containerBackground` renders
    /// nothing (widgets are snapshotted out of process, and glass is a
    /// live compositing effect), and supplying `Color.clear` here doesn't
    /// reveal glass either — it just gets the system's opaque default
    /// platter, which is white in light appearance and hides white text.
    ///
    /// So this background is what shows in Default/Dark modes, and it
    /// paints the app's own palette so the widget looks like the
    /// dashboard rather than a generic card.
    func dashboardGlassBackground() -> some View {
        containerBackground(for: .widget) {
            ZStack {
                // Blurs whatever is actually behind the widget.
                Rectangle().fill(.ultraThinMaterial)

                // The dashboard's surface, held just below opaque so the
                // blurred wallpaper still shows through the color.
                ZStack {
                    Color.dashboardPage
                    RadialGradient(
                        colors: [Color(hex: "3987E5").opacity(0.55), .clear],
                        center: UnitPoint(x: 0.08, y: -0.05), startRadius: 1, endRadius: 260
                    )
                    RadialGradient(
                        colors: [Color(hex: "D55181").opacity(0.42), .clear],
                        center: UnitPoint(x: 1.02, y: 0.12), startRadius: 1, endRadius: 240
                    )
                    RadialGradient(
                        colors: [Color(hex: "199E70").opacity(0.38), .clear],
                        center: UnitPoint(x: 0.45, y: 1.08), startRadius: 1, endRadius: 280
                    )
                }
                .opacity(0.86)

                LinearGradient(
                    colors: [Color.white.opacity(0.10), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .modifier(GlassStrokeModifier())
        // The surface above is always dark, so text defaults to light
        // rather than the adaptive `.primary`, which would flip to black
        // on a light Home Screen.
        .foregroundStyle(.white)
    }
}

private struct GlassStrokeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

@main
struct OrlandoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        AssignmentsWidget()
        RoutineWidget()
        FoldersWidget()
    }
}
