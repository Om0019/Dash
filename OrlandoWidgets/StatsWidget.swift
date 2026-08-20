import WidgetKit
import SwiftUI

struct StatsWidgetView: View {
    var body: some View {
        // No title row: iOS already prints the app name ("Dash") directly
        // beneath the widget on the Home Screen, so an in-widget title is
        // duplicated text eating a quarter of a small widget.
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statCell("Due today", "\(DashboardData.stats.dueToday)")
            statCell("This week", "\(DashboardData.stats.dueThisWeek)")
            statCell("Craft docs", "\(DashboardData.stats.craftDocs)")
            statCell("Open tasks", "\(DashboardData.stats.openTasks)")
        }
        .padding(14)
        .dashboardGlassBackground()
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(0.3)
                .foregroundStyle(Color.dashboardTextMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatsWidget: Widget {
    let kind = "StatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { _ in
            StatsWidgetView()
        }
        .configurationDisplayName("Dashboard Stats")
        .description("Due today, due this week, and Craft doc counts.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    StatsWidget()
} timeline: {
    DashboardEntry(date: .now)
}
