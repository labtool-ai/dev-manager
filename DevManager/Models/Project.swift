import Foundation

/// 一个可被管理的开发项目定义（持久化到 JSON）
struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var command: String
    var port: Int?
    var tags: [String] = []
    var autoRestart: Bool = false

    init(id: UUID = UUID(), name: String, path: String, command: String,
         port: Int? = nil, tags: [String] = [], autoRestart: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.command = command
        self.port = port
        self.tags = tags
        self.autoRestart = autoRestart
    }

    // 容错解码：老的 projects.json 缺新字段也能正常加载
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        path = try c.decode(String.self, forKey: .path)
        command = try c.decode(String.self, forKey: .command)
        port = try c.decodeIfPresent(Int.self, forKey: .port)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        autoRestart = try c.decodeIfPresent(Bool.self, forKey: .autoRestart) ?? false
    }
}
