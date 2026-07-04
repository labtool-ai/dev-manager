import Foundation

/// 启动 profile：一组命名的项目组合（可跨 tag），一键按顺序全启动。
struct Profile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var projectIDs: [UUID] = []

    init(id: UUID = UUID(), name: String = "", projectIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.projectIDs = projectIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        projectIDs = try c.decodeIfPresent([UUID].self, forKey: .projectIDs) ?? []
    }
}

enum ProfileStore {
    private static var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DevManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("profiles.json")
    }

    static func load() -> [Profile] {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([Profile].self, from: data) else { return [] }
        return list
    }

    static func save(_ profiles: [Profile]) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(profiles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
