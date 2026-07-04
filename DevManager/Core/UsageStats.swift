import Foundation
import Observation

enum HeatmapMode: String, CaseIterable { case daily, weekly, cumulative }

/// 一次运行记录（进程退出时落一条）
struct RunEvent: Codable, Identifiable {
    var id = UUID()
    var name: String
    var tag: String
    var start: Date
    var durationSec: Double
    var crashed: Bool = false

    init(id: UUID = UUID(), name: String, tag: String,
         start: Date, durationSec: Double, crashed: Bool = false) {
        self.id = id; self.name = name; self.tag = tag
        self.start = start; self.durationSec = durationSec; self.crashed = crashed
    }

    // 容错解码：老记录没有 crashed 字段也能加载
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        tag = try c.decode(String.self, forKey: .tag)
        start = try c.decode(Date.self, forKey: .start)
        durationSec = try c.decode(Double.self, forKey: .durationSec)
        crashed = try c.decodeIfPresent(Bool.self, forKey: .crashed) ?? false
    }
}

/// 使用统计：记录每次运行并聚合出各种指标，持久化到 stats.json
@Observable
@MainActor
final class UsageStats {
    private(set) var events: [RunEvent] = []

    private let cal = Calendar.current

    init() { load() }

    func record(name: String, tag: String, start: Date, end: Date, crashed: Bool = false) {
        let dur = max(0, end.timeIntervalSince(start))
        events.append(RunEvent(name: name, tag: tag, start: start, durationSec: dur, crashed: crashed))
        // 只保留最近两年，防止无限增长
        let cutoff = cal.date(byAdding: .year, value: -2, to: Date()) ?? .distantPast
        events.removeAll { $0.start < cutoff }
        save()
    }

    /// 清空所有记录（用于清除示例数据）
    func clear() {
        events.removeAll()
        save()
    }

    // MARK: - 汇总指标

    var totalRuns: Int { events.count }
    var totalRuntimeSec: Double { events.reduce(0) { $0 + $1.durationSec } }
    var longestRunSec: Double { events.map(\.durationSec).max() ?? 0 }
    var avgRuntimeSec: Double { events.isEmpty ? 0 : totalRuntimeSec / Double(events.count) }

    /// 最常用项目（名字 → 次数）前 N
    func topProjects(_ n: Int = 5) -> [(name: String, count: Int)] {
        Dictionary(grouping: events, by: \.name)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(n)
            .map { $0 }
    }

    var distinctTags: Int { Set(events.map(\.tag).filter { !$0.isEmpty }).count }

    var crashCount: Int { events.filter(\.crashed).count }

    /// 最活跃的小时（0–23），无数据返回 nil
    var mostActiveHour: Int? {
        guard !events.isEmpty else { return nil }
        let byHour = Dictionary(grouping: events) { cal.component(.hour, from: $0.start) }
            .mapValues(\.count)
        return byHour.max { $0.value < $1.value }?.key
    }

    // MARK: - 热力图 & 连续天数

    /// start-of-day → 当天运行次数
    func dailyCounts() -> [Date: Int] {
        Dictionary(grouping: events) { cal.startOfDay(for: $0.start) }
            .mapValues(\.count)
    }

    private func startOfWeek(_ d: Date) -> Date {
        let day = cal.startOfDay(for: d)
        let weekday = cal.component(.weekday, from: day) // 1 = Sunday
        return cal.date(byAdding: .day, value: -(weekday - 1), to: day) ?? day
    }

    /// 按模式给热力图上色用的每日数值
    func countsByDay(_ mode: HeatmapMode) -> [Date: Int] {
        let daily = dailyCounts()
        guard mode != .daily else { return daily }
        guard let first = events.map({ cal.startOfDay(for: $0.start) }).min() else { return [:] }
        let today = cal.startOfDay(for: Date())

        switch mode {
        case .daily:
            return daily
        case .weekly:
            // 每天取所在周的总次数（整列同一深浅）
            var weekTotal: [Date: Int] = [:]
            for (d, c) in daily { weekTotal[startOfWeek(d), default: 0] += c }
            var res: [Date: Int] = [:]
            var day = first
            while day <= today {
                res[day] = weekTotal[startOfWeek(day)] ?? 0
                day = cal.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(1)
                if day <= first { break }
            }
            return res
        case .cumulative:
            // 从首日到今天的累计次数（左浅右深的爬坡）
            var res: [Date: Int] = [:]
            var running = 0
            var day = first
            while day <= today {
                running += daily[day] ?? 0
                res[day] = running
                day = cal.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(1)
                if day <= first { break }
            }
            return res
        }
    }

    private var activeDays: Set<Date> { Set(events.map { cal.startOfDay(for: $0.start) }) }

    var currentStreak: Int {
        let active = activeDays
        var day = cal.startOfDay(for: Date())
        if !active.contains(day) {
            guard let y = cal.date(byAdding: .day, value: -1, to: day), active.contains(y) else { return 0 }
            day = y
        }
        var streak = 0
        while active.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    var longestStreak: Int {
        let days = activeDays.sorted()
        var best = 0, cur = 0
        var prev: Date?
        for d in days {
            if let p = prev, cal.date(byAdding: .day, value: 1, to: p) == d { cur += 1 } else { cur = 1 }
            best = max(best, cur)
            prev = d
        }
        return best
    }

    // MARK: - 持久化

    private var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DevManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("stats.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([RunEvent].self, from: data) else { return }
        events = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
