import Foundation

/// 更新日志：从 CDN 拉一个 changelog.json 渲染版本历史。和 appcast 一起静态托管。
struct ChangelogRelease: Decodable {
    let version: String
    let date: String
    let entries: [ChangelogEntry]
}

struct ChangelogEntry: Decodable {
    let kind: String            // new / fixed / improved …
    let text: String            // 单语兜底
    let textZh: String?
    let textEn: String?

    enum CodingKeys: String, CodingKey {
        case kind, text
        case textZh = "text_zh"
        case textEn = "text_en"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(String.self, forKey: .kind)
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        textZh = try? c.decodeIfPresent(String.self, forKey: .textZh)
        textEn = try? c.decodeIfPresent(String.self, forKey: .textEn)
    }

    func localized(_ lang: Localization.Lang) -> String {
        switch lang {
        case .zh: return textZh ?? text
        case .en: return textEn ?? text
        }
    }
}

enum Changelog {
    static let url = URL(string: "https://cdn.xdclab.com/devmanager/changelog.json")

    static func fetch() async -> [ChangelogRelease] {
        guard let base = url else { return [] }
        // 加唯一时间戳参数：URL 每次不同，绕过 CDN 边缘缓存，总回源拿最新
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        guard let fresh = comps?.url else { return [] }
        var req = URLRequest(url: fresh)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            return try JSONDecoder().decode([ChangelogRelease].self, from: data)
        } catch {
            return []
        }
    }
}
