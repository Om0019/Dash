import WidgetKit
import SwiftUI

struct AssignmentsWidgetView: View {
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Assignments")
                    .font(.caption.weight(.semibold))
                Spacer()
                liveBadge
            }

            if DashboardData.assignments.isEmpty {
                Text(DashboardData.emptyAssignmentsNote)
                    .font(.caption2)
                    .foregroundStyle(Color.dashboardTextSecondary)
                    .lineLimit(family == .systemLarge ? 6 : 3)
            } else {
                let visible = family == .systemLarge ? DashboardData.assignments : Array(DashboardData.assignments.prefix(2))
                VStack(spacing: 5) {
                    ForEach(visible) { item in
                        HStack(alignment: .top, spacing: 7) {
                            Capsule()
                                .fill(item.severity == .critical ? Color.dashboardStatusCritical : Color.dashboardStatusWarning)
                                .frame(width: 3)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.course.uppercased())
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.dashboardTextMuted)
                                Text(item.title)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(item.dueText)
                                .font(.system(size: 9))
                                .foregroundStyle(Color.dashboardTextSecondary)
                        }
                        // A Capsule has no intrinsic height, so without
                        // this the severity bar stretches to fill the whole
                        // widget instead of matching its row.
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .dashboardGlassBackground()
    }

    private var liveBadge: some View {
        Text("LIVE")
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.16))
            .foregroundStyle(Color.green)
            .clipShape(Capsule())
    }
}

struct AssignmentsWidget: Widget {
    let kind = "AssignmentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { _ in
            AssignmentsWidgetView()
        }
        .configurationDisplayName("Assignments")
        .description("Upcoming assignments synced from your Canvas calendar feed.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    AssignmentsWidget()
} timeline: {
    DashboardEntry(date: .now)
}
