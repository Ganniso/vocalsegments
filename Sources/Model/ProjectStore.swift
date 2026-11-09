import Foundation

/// Хранение проектов: JSON в Documents/projects/<id>.json, записи — rec_<id>.wav.
final class ProjectStore {
    private let dir: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("projects", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func recordingURL(projectId: String) -> URL {
        dir.appendingPathComponent("rec_\(projectId).wav")
    }

    func save(_ project: Project) {
        let url = dir.appendingPathComponent("\(project.id).json")
        if let data = try? JSONEncoder().encode(project) {
            try? data.write(to: url)
        }
    }

    func list() -> [Project] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Project.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func delete(_ project: Project) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(project.id).json"))
        try? FileManager.default.removeItem(at: recordingURL(projectId: project.id))
    }

    func lastProjectId() -> String? { UserDefaults.standard.string(forKey: "lastProject") }
    func setLastProjectId(_ id: String) { UserDefaults.standard.set(id, forKey: "lastProject") }

    /// Восстанавливает URL исходного файла из bookmark.
    func resolveURL(_ project: Project) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: project.bookmarkData,
                                 options: .withoutUI,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return nil }
        return url
    }
}
