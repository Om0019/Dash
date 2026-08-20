import WidgetKit
import SwiftUI

struct RoutineWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Face Care — Today")
                .font(.caption.weight(.semibold))

            HStack(alignment: .top, spacing: 12) {
                routineColumn(title: "☀️ AM", steps: DashboardData.amRoutine)
                routineColumn(title: "🌙 PM", steps: DashboardData.pmRoutine)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .dashboardGlassBackground()
    }

    private func routineColumn(title: String, steps: [RoutineStep]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.dashboardTextMuted)
            ForEach(steps) { step in
                HStack(spacing: 4) {
                    Text("\(step.step)")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.dashboardTextMuted)
                        .frame(width: 10, alignment: .leading)
                    Text(step.name)
                        .font(.system(size: 9.5))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RoutineWidget: Widget {
    let kind = "RoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { _ in
            RoutineWidgetView()
        }
        .configurationDisplayName("Face Care Routine")
        .description("Today's AM and PM skincare steps from Craft.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    RoutineWidget()
} timeline: {
    DashboardEntry(date: .now)
}
