import WidgetKit
import SwiftUI

struct FoldersWidgetView: View {
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Craft Docs — This Semester")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            let folders = family == .systemLarge ? DashboardData.folders : Array(DashboardData.folders.prefix(2))
            VStack(spacing: 5) {
                ForEach(folders) { folder in
                    HStack(spacing: 7) {
                        Text(folder.emoji)
                            .font(.system(size: 11))
                            .frame(width: 20, height: 20)
                            .background(Color(hex: folder.colorHex).opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(folder.name)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }

            if family == .systemLarge {
                Spacer(minLength: 2)
                Text("\(DashboardData.stats.craftDocs) total docs")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.dashboardTextMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .dashboardGlassBackground()
    }
}

struct FoldersWidget: Widget {
    let kind = "FoldersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { _ in
            FoldersWidgetView()
        }
        .configurationDisplayName("Craft Folders")
        .description("Your class folders in Craft, at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    FoldersWidget()
} timeline: {
    DashboardEntry(date: .now)
}
