import Foundation
import WidgetKit

/// Talks to Craft's Connect REST API directly (the same API backing Craft's
/// MCP connector) to build a live `CraftSnapshot`. The base URL carries an
/// account-scoped access token, so it's entered by the user in the
/// Connections screen and read from `CraftConnectConfig` rather than
/// hardcoded — see that type's doc comment.
enum CraftError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        "Add your Craft Connect link in Connections first."
    }
}

@MainActor
final class CraftService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncError: String?

    private struct ItemsResponse<T: Decodable>: Decodable {
        let items: [T]
    }

    private struct APIFolder: Decodable {
        let id: String
        let name: String
        let documentCount: Int
    }

    private struct APIDocument: Decodable {
        let id: String
        let title: String
    }

    private struct APITask: Decodable {
        let id: String
    }

    /// Known course folders keep the same emoji/color as the original
    /// dashboard mock; anything else gets a generated look so new Craft
    /// folders still render sensibly.
    private static let folderStyles: [String: (emoji: String, colorHex: String)] = [
        "AC Circuits & Intro to Power": ("⚡", "3987E5"),
        "Intro to Computer Organization": ("🖥️", "D95926"),
        "Introduction to VLSI": ("🔬", "199E70"),
        "Engineering Capstone I": ("🎓", "C98500"),
        "EE 325": ("🎚️", "E66767"),
        "EE 240": ("🧮", "9085E9"),
        "EE 317": ("📘", "D55181"),
        "EE 300": ("📗", "4A8F2F"),
        "Imported Notes": ("🗂️", "75746E"),
    ]

    private static let fallbackColors = ["6C63FF", "D55181", "4C9F70", "E66767", "3987E5", "C98500"]

    /// Craft's `/folders` endpoint also returns its built-in pseudo-folders
    /// (Unsorted, Daily Notes, Recently Deleted, Templates — stable ids
    /// "unsorted"/"daily_notes"/"trash"/"templates") alongside real
    /// user-created ones. Those aren't folders you'd navigate to, so they'd
    /// otherwise pollute the chip row and double-count against the
    /// dedicated `location=unsorted` fetch below.
    private static let systemFolderIDs: Set<String> = ["unsorted", "daily_notes", "trash", "templates"]

    private func style(for folderName: String) -> (emoji: String, colorHex: String) {
        if let known = Self.folderStyles[folderName] { return known }
        let index = abs(folderName.hashValue) % Self.fallbackColors.count
        return ("📁", Self.fallbackColors[index])
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        guard let baseURL = CraftConnectConfig.url else { throw CraftError.notConfigured }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func sync() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            async let foldersResponse: ItemsResponse<APIFolder> = get("folders")
            async let unsortedResponse: ItemsResponse<APIDocument> = get("documents", query: [URLQueryItem(name: "location", value: "unsorted")])
            async let tasksResponse: ItemsResponse<APITask> = get("tasks", query: [URLQueryItem(name: "scope", value: "active")])

            let (folders, unsorted, tasks) = try await (foldersResponse, unsortedResponse, tasksResponse)

            // Craft Connect's `/documents?folder=<id>` filter doesn't
            // actually scope by folder (verified: it returns the same full
            // document list no matter which id is passed), so per-folder
            // "recent doc" titles can't be trusted. `location=unsorted` and
            // the plain `/folders` document counts are reliable, so recent
            // activity is built from unsorted docs only.
            let recentDocs: [CraftDocSummary] = unsorted.items.prefix(7).map {
                CraftDocSummary(id: $0.id, title: $0.title.isEmpty ? "Untitled" : $0.title, folder: "Unsorted", colorHex: "75746E")
            }

            let realFolders = folders.items.filter { !Self.systemFolderIDs.contains($0.id) }

            let folderSummaries: [CraftFolderSummary] = realFolders.map { folder in
                let folderStyle = style(for: folder.name)
                return CraftFolderSummary(id: folder.id, name: folder.name, emoji: folderStyle.emoji, colorHex: folderStyle.colorHex, docCount: folder.documentCount)
            }

            let totalDocs = realFolders.reduce(0) { $0 + $1.documentCount } + unsorted.items.count

            let snapshot = CraftSnapshot(
                lastSynced: Date(),
                totalDocs: totalDocs,
                openTasks: tasks.items.count,
                folders: folderSummaries,
                recentDocs: Array(recentDocs.prefix(8))
            )
            CraftStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }
}
