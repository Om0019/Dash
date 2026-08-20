import SwiftUI

struct ContentView: View {
    @StateObject private var calendarService = CalendarService()
    @StateObject private var craftService = CraftService()

    private var lastSyncedText: String {
        let craft = DashboardData.craftSnapshot.lastSynced
        let cal = calendarService.authState == .authorized ? DashboardData.calendarSnapshot.lastSynced : .distantPast
        let last = max(craft, cal)
        guard last != .distantPast else { return "Not synced yet" }
        return "Synced \(last.formatted(.relative(presentation: .named)))"
    }

    /// Settings is an overlay rather than a navigation push so the floating
    /// button stays on screen and can morph into its own back control.
    @State private var showSettings = false

    var body: some View {
        ZStack {
            backgroundGlow

            if showSettings {
                SettingsView(calendarService: calendarService, craftService: craftService)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                dashboard
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomLeading) {
            settingsPill
        }
        .tint(Color.dashboardAccent)
        .task {
            calendarService.refreshAuthState()
            async let calendarSync: Void = calendarService.authState == .authorized ? calendarService.sync() : ()
            async let craftSync: Void = craftService.sync()
            _ = await (calendarSync, craftSync)
        }
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            syncStatus
            calendarStatusCard
            statsRow

            ScrollView {
                VStack(spacing: 12) {
                    assignmentsCard
                    faceCareCard
                    craftFoldersCard
                    recentActivityCard
                }
                // Clears the floating button so the last card can always
                // be scrolled out from under it.
                .padding(.bottom, 76)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(EdgeInsets(top: 8, leading: 18, bottom: 0, trailing: 18))
    }

    // MARK: - Status line

    private var syncStatus: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.dashboardStatusGood)
                .frame(width: 5, height: 5)
            Text(lastSyncedText)
                .font(.system(size: 11))
                .foregroundStyle(Color.dashboardTextMuted)
        }
    }

    // MARK: - Floating settings pill

    private var settingsPill: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                showSettings.toggle()
            }
        } label: {
            Image(systemName: showSettings ? "chevron.left" : "gearshape.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.dashboardTextSecondary)
                // Symbol replace morphs the glyphs; the full turn spins the
                // gear on the way. It has to be a whole 360° — a partial
                // angle would leave the chevron permanently rotated,
                // pointing somewhere other than back.
                .contentTransition(.symbolEffect(.replace))
                .rotationEffect(.degrees(showSettings ? 360 : 0))
                .frame(width: 48, height: 48)
                .glassCapsule()
        }
        .buttonStyle(.plain)
        .padding(.leading, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Stats

    private var statsRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            StatTile(label: "Due today", value: "\(DashboardData.stats.dueToday)")
            StatTile(label: "This week", value: "\(DashboardData.stats.dueThisWeek)")
            StatTile(label: "Craft docs", value: "\(DashboardData.stats.craftDocs)")
            StatTile(label: "Open tasks", value: "\(DashboardData.stats.openTasks)")
        }
    }

    // MARK: - Assignments

    private var assignmentsCard: some View {
        GlassCard(title: "Assignments", badge: .live, note: "Live from your calendar — iOS + Google, synced automatically.") {
            if DashboardData.assignments.isEmpty {
                // The banner above already handles the disconnected case —
                // don't repeat the setup instructions a second time here.
                Text(calendarService.authState == .authorized
                     ? "Nothing due in the next two weeks."
                     : "Nothing to show yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashboardTextSecondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(DashboardData.assignments.prefix(8)) { item in
                        AssignRow(item: item)
                        if item.id != DashboardData.assignments.prefix(8).last?.id {
                            Divider().overlay(Color.dashboardGridline)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Face care

    private var faceCareCard: some View {
        GlassCard(
            title: "Today's face care routine — \(Date().formatted(.dateTime.weekday(.abbreviated)))",
            badge: .live,
            note: "Pulled from your \"Weekly Face Routine Schedule\" note in Craft."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    RoutineColumn(title: "☀️ AM", steps: DashboardData.amRoutine)
                    RoutineColumn(title: "🌙 PM", steps: DashboardData.pmRoutine)
                }

                Callout {
                    (Text("How to apply: ").fontWeight(.semibold).foregroundStyle(.white)
                     + Text("cleanser first, then treatments thinnest-to-thickest (Vitamin C serum, then salicylic acid spot-treated on the nose), moisturizer last. Let each layer sit ~1 min before the next. AM moisturizer has SPF 30 built in — no separate sunscreen needed."))
                }
            }
        }
    }

    // MARK: - Craft folders

    private var primaryFolders: [CraftFolderSummary] {
        DashboardData.folders
            .filter { DashboardData.primaryFolderOrder.contains($0.name) }
            .sorted { a, b in
                (DashboardData.primaryFolderOrder.firstIndex(of: a.name) ?? 0)
                    < (DashboardData.primaryFolderOrder.firstIndex(of: b.name) ?? 0)
            }
    }

    private var otherFolders: [CraftFolderSummary] {
        DashboardData.folders.filter { !DashboardData.primaryFolderOrder.contains($0.name) }
    }

    private var craftFoldersCard: some View {
        GlassCard(title: "Craft docs — this semester", badge: .live, note: "Tap a class to open its folder in Craft.") {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(primaryFolders) { folder in
                        FolderCard(folder: folder)
                    }
                }

                if !otherFolders.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OTHER CRAFT FOLDERS")
                            .font(.system(size: 9.5, weight: .medium))
                            .tracking(0.5)
                            .foregroundStyle(Color.dashboardTextMuted)

                        FlowChips(folders: otherFolders)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Recent activity

    private var recentActivityCard: some View {
        GlassCard(title: "Recent Craft activity", badge: .live, note: "Order reflects Craft's own document list, not real timestamps.") {
            VStack(spacing: 0) {
                ForEach(DashboardData.recentDocs) { doc in
                    DocRow(doc: doc)
                    if doc.id != DashboardData.recentDocs.last?.id {
                        Divider().overlay(Color.dashboardGridline)
                    }
                }
            }
        }
    }

    private var backgroundGlow: some View {
        AmbientGlow()
            .ignoresSafeArea()
    }

    /// Compact one-line banner rather than a full card: this is onboarding
    /// chrome, and the full explanation already lives in the Connections
    /// screen — it shouldn't push the actual dashboard below the fold.
    @ViewBuilder
    private var calendarStatusCard: some View {
        switch calendarService.authState {
        case .authorized:
            EmptyView()
        case .unknown, .denied:
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dashboardAccent)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Calendar not connected")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(calendarService.authState == .denied ? "Turn on access in iOS Settings" : "Assignments stay empty until you do")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dashboardTextMuted)
                }

                Spacer(minLength: 8)

                if calendarService.authState == .unknown {
                    Button("Connect") {
                        Task { await calendarService.requestAccessAndSync() }
                    }
                    .buttonStyle(AccentButtonStyle())
                } else {
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(AccentButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .background(Color.dashboardAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dashboardAccent.opacity(0.35), lineWidth: 1))
        }
    }
}

// MARK: - Shared building blocks

private enum Badge { case live, sample }

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Four tiles across a 393pt screen leaves ~60pt of text room —
            // labels must stay on one line or the row goes ragged and the
            // numbers stop aligning.
            Text(label.uppercased())
                .font(.system(size: 9.5))
                .tracking(0.3)
                .foregroundStyle(Color.dashboardTextMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: 21, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .glassSurface(cornerRadius: 12)
    }
}

private struct GlassCard<Content: View>: View {
    let title: String
    let badge: Badge?
    let note: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                Spacer()
                if let badge {
                    BadgeView(badge: badge)
                }
            }
            if let note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashboardTextMuted)
                    .lineSpacing(2)
                    .padding(.bottom, 4)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface()
    }
}

private struct BadgeView: View {
    let badge: Badge

    var body: some View {
        Text(badge == .live ? "LIVE" : "SAMPLE")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                (badge == .live ? Color(hex: "0CA30C") : Color.dashboardStatusWarning).opacity(0.16),
                in: Capsule()
            )
            .foregroundStyle(badge == .live ? Color(hex: "3FD83F") : Color.dashboardStatusWarning)
    }
}

private struct AssignRow: View {
    let item: AssignmentItem

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Capsule()
                .fill(item.severity == .critical ? Color.dashboardStatusCritical : Color.dashboardStatusWarning)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.course.uppercased())
                    .font(.system(size: 9.5))
                    .tracking(0.3)
                    .foregroundStyle(Color.dashboardTextMuted)
                Text(item.title)
                    .font(.system(size: 12))
            }
            Spacer(minLength: 6)
            Text(item.dueText)
                .font(.system(size: 11))
                .foregroundStyle(Color.dashboardTextSecondary)
        }
        .padding(.vertical, 6)
    }
}

private struct RoutineColumn: View {
    let title: String
    let steps: [RoutineStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.dashboardTextMuted)
                .padding(.bottom, 6)
            ForEach(steps) { step in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(step.step)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.dashboardTextMuted)
                        .frame(width: 12, alignment: .leading)
                    Text(step.name)
                        .font(.system(size: 12))
                }
                .padding(.vertical, 5)
                if step.step != steps.last?.step {
                    Divider().overlay(Color.dashboardGridline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Callout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.system(size: 11))
            .foregroundStyle(Color.dashboardTextSecondary)
            .lineSpacing(3)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .background(Color.dashboardGlassBg2, in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "199E70")).frame(width: 2)
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dashboardGlassBorder, lineWidth: 1))
    }
}

private struct FolderCard: View {
    let folder: CraftFolderSummary

    var body: some View {
        Link(destination: URL(string: "craftdocs://open?spaceId=\(DashboardData.craftSpaceID)&blockId=\(folder.id)")!) {
            HStack(spacing: 8) {
                Text(folder.emoji)
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: folder.colorHex).opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
                Text(folder.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                Spacer(minLength: 4)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashboardTextMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .background(Color.dashboardGlassBg2, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dashboardGlassBorder, lineWidth: 1))
        }
    }
}

private struct FlowChips: View {
    let folders: [CraftFolderSummary]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(folders) { folder in
                Link(destination: URL(string: "craftdocs://open?spaceId=\(DashboardData.craftSpaceID)&blockId=\(folder.id)")!) {
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: folder.colorHex)).frame(width: 6, height: 6)
                        Text(folder.name == "Imported Notes" ? "Imported" : folder.name)
                            .font(.system(size: 10.5))
                    }
                    .foregroundStyle(Color.dashboardTextSecondary)
                    .padding(.leading, 7)
                    .padding(.trailing, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(Color.dashboardGlassBg2, in: Capsule())
                    .overlay(Capsule().stroke(Color.dashboardGlassBorder, lineWidth: 1))
                }
            }
        }
    }
}

/// Wraps its children onto multiple rows, left-to-right, like CSS
/// `flex-wrap: wrap` — used for the "Other Craft folders" chip row.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct DocRow: View {
    let doc: CraftDocSummary

    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(Color(hex: doc.colorHex)).frame(width: 7, height: 7)
            Text(doc.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Text(doc.folder)
                .font(.system(size: 10))
                .foregroundStyle(Color.dashboardTextSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.dashboardGlassBg2, in: Capsule())
                .overlay(Capsule().stroke(Color.dashboardGlassBorder, lineWidth: 1))
                .fixedSize()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
