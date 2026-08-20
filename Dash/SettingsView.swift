import EventKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var craftService: CraftService

    @State private var craftURLText: String = CraftConnectConfig.urlString ?? ""
    @State private var isEditingCraftURL: Bool = CraftConnectConfig.urlString == nil

    private var calendarsBySource: [(source: String, calendars: [EKCalendar])] {
        Dictionary(grouping: calendarService.availableCalendars) { $0.source.title }
            .sorted { $0.key < $1.key }
            .map { (source: $0.key, calendars: $0.value) }
    }

    /// Presented as an overlay from the dashboard, not pushed — the
    /// floating button that opens this also serves as its back control, so
    /// there's no navigation bar to supply a title.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connections")
                .font(.system(size: 19, weight: .semibold))
                .padding(.horizontal, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    calendarSection
                    if calendarService.authState == .authorized {
                        calendarPickerSections
                    }
                    craftSection
                }
                .padding(.horizontal, 18)
                // Clears the floating back button.
                .padding(.bottom, 76)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { calendarService.refreshAuthState() }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        SettingsSection(
            title: "Calendar",
            footer: "Google Calendar isn't a separate connection — add your Google account under iOS Settings → Calendar → Accounts and its calendars appear below automatically."
        ) {
            StatusRow(
                title: "iOS Calendar",
                detail: calendarStatusText,
                isConnected: calendarService.authState == .authorized
            )

            RowDivider()

            if calendarService.authState == .authorized {
                ActionRow(
                    title: "Add Google account",
                    icon: "arrow.up.right.square",
                    trailing: lastCalendarSyncText
                ) {
                    openSystemSettings()
                }
            } else {
                ActionRow(
                    title: calendarService.authState == .denied ? "Open iOS Settings" : "Connect Calendar",
                    icon: calendarService.authState == .denied ? "gear" : "calendar.badge.plus",
                    trailing: nil
                ) {
                    if calendarService.authState == .denied {
                        openSystemSettings()
                    } else {
                        Task { await calendarService.requestAccessAndSync() }
                    }
                }
            }
        }
    }

    private var calendarPickerSections: some View {
        ForEach(calendarsBySource, id: \.source) { group in
            SettingsSection(title: group.source) {
                ForEach(Array(group.calendars.enumerated()), id: \.element.calendarIdentifier) { index, calendar in
                    Toggle(isOn: Binding(
                        get: { calendarService.selectedCalendarIDs.contains(calendar.calendarIdentifier) },
                        set: { calendarService.setCalendar(calendar, included: $0) }
                    )) {
                        HStack(spacing: 9) {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 9, height: 9)
                            Text(calendar.title)
                                .font(.system(size: 13.5))
                                .foregroundStyle(.white)
                        }
                    }
                    .tint(Color.dashboardAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index != group.calendars.count - 1 {
                        RowDivider()
                    }
                }
            }
        }
    }

    // MARK: - Craft

    private var craftSection: some View {
        SettingsSection(
            title: "Craft",
            footer: "Reads folders, documents, and tasks from your Craft space via an account-scoped Connect link. Find it in Craft: Space Settings → Connect API → Create/Copy link. This is stored only on your device, never in the app's source."
        ) {
            StatusRow(
                title: "Craft",
                detail: CraftConnectConfig.urlString == nil ? "Not connected" : "Connected via Craft Connect API",
                isConnected: CraftConnectConfig.urlString != nil
            )

            RowDivider()

            if isEditingCraftURL {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("https://connect.craft.do/links/…", text: $craftURLText)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    ActionRow(title: "Save link", icon: "checkmark.circle", trailing: nil) {
                        let trimmed = craftURLText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        CraftConnectConfig.urlString = trimmed
                        isEditingCraftURL = false
                        Task { await craftService.sync() }
                    }
                }
            } else {
                ActionRow(
                    title: craftService.isSyncing ? "Syncing…" : "Sync now",
                    icon: "arrow.clockwise",
                    trailing: craftService.isSyncing ? nil : "Synced \(DashboardData.craftSnapshot.lastSynced.formatted(.relative(presentation: .named)))",
                    showsProgress: craftService.isSyncing
                ) {
                    Task { await craftService.sync() }
                }

                RowDivider()

                ActionRow(title: "Change Craft link", icon: "pencil", trailing: nil) {
                    craftURLText = CraftConnectConfig.urlString ?? ""
                    isEditingCraftURL = true
                }
            }

            if let error = craftService.lastSyncError {
                RowDivider()
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashboardStatusCritical)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Helpers

    private var calendarStatusText: String {
        switch calendarService.authState {
        case .authorized:
            return "\(calendarService.selectedCalendarIDs.count) of \(calendarService.availableCalendars.count) calendars syncing"
        case .denied:
            return "Access denied"
        case .unknown:
            return "Not connected"
        }
    }

    private var lastCalendarSyncText: String? {
        let last = CalendarStore.load().lastSynced
        guard last != .distantPast else { return nil }
        return "Synced \(last.formatted(.relative(presentation: .named)))"
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Rows

private struct StatusRow: View {
    let title: String
    let detail: String
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashboardTextMuted)
            }
            Spacer(minLength: 8)
            Image(systemName: isConnected ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.system(size: 15))
                .foregroundStyle(isConnected ? Color.dashboardStatusGood : Color.dashboardStatusWarning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct ActionRow: View {
    let title: String
    let icon: String
    var trailing: String?
    var showsProgress = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.dashboardAccent)
                        .frame(width: 16)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dashboardAccent)
                        .frame(width: 16)
                }

                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.dashboardAccent)

                Spacer(minLength: 8)

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dashboardTextMuted)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AmbientGlow().ignoresSafeArea()
        SettingsView(calendarService: CalendarService(), craftService: CraftService())
    }
    .preferredColorScheme(.dark)
}
