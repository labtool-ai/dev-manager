import Foundation
import Observation
import AppKit

/// 全局大脑：菜单栏和主窗口共享同一个实例，任何一处启停两处同步刷新。
/// 项目定义持久化到 JSON（见 ProjectStore）。
@Observable
@MainActor
final class ProcessManager {
    private(set) var processes: [ManagedProcess] = []
    let stats = UsageStats()

    // 合并日志流:所有运行中项目的输出汇到一起
    struct MergedLine: Identifiable { let id = UUID(); let name: String; let line: String }
    private(set) var mergedLog: [MergedLine] = []
    private let maxMerged = 3000

    var profiles: [Profile] = []
    @ObservationIgnored private var controlServer: ControlServer?

    func startControlServer() {
        if controlServer == nil { controlServer = ControlServer(manager: self) }
        controlServer?.start()
    }

    init() {
        let projects = ProjectStore.load() ?? Self.seedProjects()
        processes = projects.map { ManagedProcess(project: $0, stats: stats) }
        processes.forEach { $0.manager = self }
        profiles = ProfileStore.load()
        if ProjectStore.load() == nil { persist() } // 首次落盘种子
        // app 退出：给正在跑的会话记一条统计 + 结束其进程树（避免最长运行丢失 + 孤儿进程残留）
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopAllOnQuit() }
        }
    }

    /// app 退出：给正在运行的项目各记一条统计，并结束其进程树（否则本应用启动的 dev 进程会残留）。
    func stopAllOnQuit() {
        for p in processes where p.state == .running {
            p.flushRunningRun()
            p.terminateTreeNow()
        }
    }

    // MARK: - Profiles（启动组合）

    func saveProfile(_ profile: Profile) {
        if let i = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[i] = profile
        } else {
            profiles.append(profile)
        }
        ProfileStore.save(profiles)
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        ProfileStore.save(profiles)
    }

    /// 按 profile 里的顺序错峰启动（先起的先就绪，适配"先后端再前端"）
    /// 按组合里存的顺序「编排」启动:起一个 → 等它真就绪 → 再起下一个。
    /// 就绪判定:声明了端口→等端口通(isReady);没声明→探到监听端口 or 起够 1.5s 放行;
    /// 都带 40s 超时兜底,某个卡住/崩了也不会拖住整组。
    func startProfile(_ profile: Profile) {
        let procs = profile.projectIDs.compactMap { process(for: $0) }
        Task { @MainActor in
            for p in procs where p.state == .stopped {
                p.start()
                await waitUntilReady(p, timeout: 40)
            }
        }
    }

    private func waitUntilReady(_ p: ManagedProcess, timeout: TimeInterval) async {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if p.state == .stopped { return }          // 崩了/退了 → 别再等,继续起下一个
            if p.isReady { return }                    // 声明端口且端口已通
            if p.project.port == nil {
                if p.detectedPort != nil { return }    // 没声明端口但已探到监听端口
                if p.state == .running, Date().timeIntervalSince(start) >= 1.5 { return }  // 无从判断 → 短暂 grace 后放行
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        // 超时:声明端口却迟迟没通(慢构建等)→ 也放行,继续起下一个
    }

    func projectsIn(_ profile: Profile) -> [ManagedProcess] {
        profile.projectIDs.compactMap { process(for: $0) }
    }

    func pushMerged(name: String, _ line: String) {
        mergedLog.append(MergedLine(name: name, line: line))
        if mergedLog.count > maxMerged { mergedLog.removeFirst(mergedLog.count - maxMerged) }
    }

    func clearMerged() { mergedLog.removeAll() }

    var runningCount: Int {
        processes.filter { $0.state == .running }.count
    }

    func process(for id: UUID) -> ManagedProcess? {
        processes.first { $0.id == id }
    }

    /// 侧栏按首个 tag 分组（同一 tag 的前后端会归到一组）
    var grouped: [(tag: String, items: [ManagedProcess])] {
        Dictionary(grouping: processes) { $0.project.tags.first ?? "Untagged" }
            .sorted { $0.key < $1.key }
            .map { (tag: $0.key, items: $0.value) }
    }

    // MARK: - 端口冲突

    enum PortConflict: Identifiable {
        case ours(port: Int, occupier: ManagedProcess)
        case external(port: Int, pid: Int32, name: String)

        nonisolated var id: String {
            switch self {
            case .ours(let p, _): "ours-\(p)"
            case .external(let p, let pid, _): "ext-\(p)-\(pid)"
            }
        }
        var port: Int {
            switch self {
            case .ours(let p, _), .external(let p, _, _): p
            }
        }
    }

    /// 启动前检查端口是否被占；被占则判断是"我们自己的项目"还是"外部进程"
    func portConflict(for proc: ManagedProcess) async -> PortConflict? {
        guard let port = proc.project.port else { return nil }
        guard let occ = await Task.detached(priority: .userInitiated, operation: {
            SystemProbe.portOccupier(port)
        }).value else { return nil }

        // 占用者 pid 是否属于我们某个运行中项目的进程树
        for p in processes where p.id != proc.id && p.state != .stopped {
            guard let root = p.rootPID else { continue }
            let tree = await Task.detached(priority: .userInitiated, operation: {
                SystemProbe.descendants(of: root)
            }).value
            if tree.contains(occ.pid) {
                return .ours(port: port, occupier: p)
            }
        }
        return .external(port: port, pid: occ.pid, name: occ.name)
    }

    /// 解决冲突后启动:停掉占用者(我们的→优雅停;外部→SIGTERM),稍候再启目标
    func resolveAndStart(_ conflict: PortConflict, target: ManagedProcess) {
        switch conflict {
        case .ours(_, let occupier):
            occupier.stop()
        case .external(_, let pid, _):
            kill(pid, SIGTERM)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            target.start()
        }
    }

    // MARK: - 整组启停（按 tag）

    func startTag(_ tag: String) {
        for p in processes where (p.project.tags.first ?? "Untagged") == tag && p.state == .stopped {
            p.start()
        }
    }

    func stopTag(_ tag: String) {
        for p in processes where (p.project.tags.first ?? "Untagged") == tag && p.state != .stopped {
            p.stop()
        }
    }

    func runningCount(inTag tag: String) -> Int {
        processes.filter { ($0.project.tags.first ?? "Untagged") == tag && $0.state != .stopped }.count
    }

    // MARK: - 增删

    /// 批量新增（一个文件夹下多条命令 → 多个项目，共享 path + tag）
    @discardableResult
    func addProjects(_ newProjects: [Project]) -> [ManagedProcess] {
        let created = newProjects.map { p -> ManagedProcess in
            let mp = ManagedProcess(project: p, stats: stats)
            mp.manager = self
            return mp
        }
        processes.append(contentsOf: created)
        persist()
        return created
    }

    /// 编辑：用新的定义替换（保持同一 id）
    func update(id: UUID, with edited: Project) {
        guard let proc = process(for: id) else { return }
        var next = edited
        next.id = id
        proc.project = next
        persist()
    }

    /// 给项目追加一个 tag
    func addTag(_ tag: String, to id: UUID) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let proc = process(for: id),
              !proc.project.tags.contains(trimmed) else { return }
        proc.project.tags.append(trimmed)
        persist()
    }

    /// 移除一个 tag
    func removeTag(_ tag: String, from id: UUID) {
        guard let proc = process(for: id) else { return }
        proc.project.tags.removeAll { $0 == tag }
        persist()
    }

    /// 拖拽排序:把 id 移到 targetID 之前
    func move(_ id: UUID, before targetID: UUID) {
        guard id != targetID,
              let from = processes.firstIndex(where: { $0.id == id }) else { return }
        let item = processes.remove(at: from)
        let to = processes.firstIndex(where: { $0.id == targetID }) ?? processes.count
        processes.insert(item, at: to)
        persist()
    }

    func delete(id: UUID) {
        guard let proc = process(for: id) else { return }
        proc.stop()
        processes.removeAll { $0.id == id }
        persist()
    }

    // MARK: - 持久化

    private func persist() {
        ProjectStore.save(processes.map(\.project))
    }

    // MARK: - 首次运行的种子数据

    private static func seedProjects() -> [Project] {
        // 用本机真实存在的项目做示例：一个文件夹、两条命令、同一个 tag
        [
            Project(name: "ark-us-vue/dev",
                    path: "~/ark-us-vue",
                    command: "npm run dev",
                    port: 5173,
                    tags: ["ark-us-vue"]),
            Project(name: "ark-us-vue/electron:dev",
                    path: "~/ark-us-vue",
                    command: "npm run electron:dev",
                    port: nil,
                    tags: ["ark-us-vue"]),
        ]
    }
}
