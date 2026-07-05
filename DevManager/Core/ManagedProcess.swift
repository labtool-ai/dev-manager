import Foundation
import Observation
import AppKit

enum RunState {
    case stopped
    case starting
    case running
}

/// 单个进程的运行时状态：Process + 日志缓冲 + 端口就绪 + 资源采样 + 自动重启。
@Observable
@MainActor
final class ManagedProcess: Identifiable {
    var project: Project
    var id: UUID { project.id }

    var state: RunState = .stopped
    var logs: [String] = []

    var isReady = false              // 端口探测通过
    var detectedURL: String?         // 从日志里解析到的 http://localhost:xxxx
    var cpu: Double?                 // 进程树 CPU% 之和
    var memMB: Double?               // 进程树内存 MB 之和
    private(set) var cpuHistory: [Double] = []   // sparkline 用,环形约 90*1.8s≈2.7min
    private(set) var memHistory: [Double] = []
    @ObservationIgnored private let historyCap = 90
    @ObservationIgnored private var memAlerted = false
    @ObservationIgnored private var cpuAlerted = false
    var detectedPort: Int?           // 从进程树实际探到的监听端口(没声明端口时用)
    var lanReachable = false         // 该端口是否绑到 0.0.0.0/*(=局域网设备可访问)
    @ObservationIgnored private var portTick = 0

    /// 实际用于 URL / 二维码的端口:优先用户声明的，否则从进程树探到的
    var effectivePort: Int? { project.port ?? detectedPort }
    var startDate: Date?             // 用于 uptime

    /// 当前进程的根 pid(用于判断谁在占端口)
    var rootPID: Int32? { process?.processIdentifier }

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var intentionalStop = false
    @ObservationIgnored private var restartPending = false
    @ObservationIgnored private var logHandle: FileHandle?
    @ObservationIgnored private let maxLogLines = 5000
    @ObservationIgnored weak var stats: UsageStats?
    @ObservationIgnored weak var manager: ProcessManager?
    @ObservationIgnored private var wasReady = false

    init(project: Project, stats: UsageStats? = nil) {
        self.project = project
        self.stats = stats
        loadPersistedLogs()
    }

    // MARK: - 就绪 / 展示

    /// 用于状态点的相位：进程活着但声明了端口且端口没起 → starting（黄），否则 running（绿）
    var phase: RunState {
        guard state == .running else { return state }
        if project.port != nil, !isReady { return .starting }
        return .running
    }

    var uptime: String? {
        guard state == .running, let start = startDate else { return nil }
        let s = Int(Date().timeIntervalSince(start))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }

    /// 浏览器打开目标：优先日志里解析到的真实地址，否则 localhost:port
    var browserURL: URL? {
        if let s = detectedURL, let u = URL(string: s) { return u }
        if let p = effectivePort { return URL(string: "http://localhost:\(p)") }
        return nil
    }

    func openInBrowser() {
        if let u = browserURL { NSWorkspace.shared.open(u) }
    }

    // MARK: - 启停

    func toggle() { state == .stopped ? start() : stop() }

    func start() {
        guard state == .stopped else { return }
        state = .starting
        isReady = false
        wasReady = false
        startDate = Date()
        intentionalStop = false

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", project.command]
        proc.currentDirectoryURL = URL(
            fileURLWithPath: (project.path as NSString).expandingTildeInPath
        )
        // 强制彩色输出：管道不是 TTY，npm/vite 等默认会关掉颜色，这里逼它们照常输出 ANSI
        var env = ProcessInfo.processInfo.environment
        env["FORCE_COLOR"] = "1"
        env["CLICOLOR_FORCE"] = "1"
        env["CLICOLOR"] = "1"
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.append(str) }
        }

        proc.terminationHandler = { [weak self] p in
            let status = p.terminationStatus
            let bySignal = p.terminationReason == .uncaughtSignal
            Task { @MainActor [weak self] in
                self?.handleTermination(status: status, bySignal: bySignal)
            }
        }

        do {
            try proc.run()
            process = proc
            state = .running
            append("▶ started: \(project.command)\n")
            startMonitoring()
        } catch {
            append("✗ failed to start: \(error.localizedDescription)\n")
            state = .stopped
            startDate = nil
        }
    }

    func stop() {
        intentionalStop = true
        terminateProcess()
    }

    func restart() {
        guard state != .stopped else { start(); return }
        restartPending = true
        terminateProcess()
    }

    /// app 退出兜底：把当前正在进行的运行落一条统计（否则退出时最长的一段运行会丢）。
    /// 只记录、置空起点，不改变进程本身状态；置空 startDate 可避免之后 handleTermination 重复记一条。
    func flushRunningRun() {
        guard state == .running, let start = startDate else { return }
        stats?.record(name: project.name,
                      tag: project.tags.first ?? "",
                      start: start, end: Date(), crashed: false)
        startDate = nil
    }

    /// app 退出时同步结束整棵进程树（SIGTERM），避免本应用启动的项目变成孤儿进程残留。
    /// 与普通 stop() 不同：不走 3 秒后 SIGKILL 的异步兜底（app 正在退出，来不及），
    /// 而是一次性对 root + 所有后代发 SIGTERM。
    func terminateTreeNow() {
        intentionalStop = true
        guard let root = rootPID else { return }
        for pid in SystemProbe.descendants(of: root) { kill(pid, SIGTERM) }
    }

    private func terminateProcess() {
        guard let proc = process, proc.isRunning else {
            if state != .stopped { handleTermination() }
            return
        }
        proc.terminate() // SIGTERM
        let pid = proc.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if proc.isRunning { kill(pid, SIGKILL) }
        }
    }

    private func handleTermination(status: Int32 = 0, bySignal: Bool = false) {
        stopMonitoring()
        process = nil
        state = .stopped
        isReady = false
        cpu = nil; memMB = nil
        cpuHistory = []; memHistory = []; memAlerted = false; cpuAlerted = false
        detectedPort = nil; lanReachable = false; portTick = 0
        // 崩溃 = 非用户主动停止，且异常退出（被信号杀 / 非零退出码）
        let crashed = !intentionalStop && (bySignal || status != 0)
        // 记录这次运行到统计
        if let start = startDate {
            stats?.record(name: project.name,
                          tag: project.tags.first ?? "",
                          start: start, end: Date(), crashed: crashed)
        }
        startDate = nil
        append(crashed ? "\n■ process crashed (code \(status))\n" : "\n■ process exited\n")
        if crashed {
            Notifier.notify(title: project.name,
                            zh: "进程崩溃（code \(status)）",
                            en: "crashed (code \(status))")
        }

        if restartPending {
            restartPending = false
            start()
        } else if !intentionalStop && project.autoRestart {
            append("↻ auto-restarting…\n")
            start()
        }
        intentionalStop = false
    }

    // MARK: - 后台采样（端口 + 资源）

    private func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sample()
                try? await Task.sleep(nanoseconds: 1_800_000_000) // 1.8s
            }
        }
    }

    private func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func sample() async {
        guard state == .running, let pid = process?.processIdentifier else { return }
        let port = project.port
        let probe = await Task.detached(priority: .utility) { () -> (Double?, Double?, Bool) in
            let tree = SystemProbe.sampleTree(root: pid)
            let open = port.map { SystemProbe.isPortOpen($0) } ?? true
            return (tree?.cpu, tree?.memMB, open)
        }.value
        cpu = probe.0
        memMB = probe.1
        isReady = probe.2

        // 资源历史(环形)+ 阈值告警
        cpuHistory.append(cpu ?? 0); if cpuHistory.count > historyCap { cpuHistory.removeFirst() }
        memHistory.append(memMB ?? 0); if memHistory.count > historyCap { memHistory.removeFirst() }
        checkResourceAlerts()

        // 每 ~5s 探一次实际监听端口 + 是否绑到局域网(二维码用)
        portTick += 1
        if portTick % 3 == 1, let pid = process?.processIdentifier {
            let dets = await Task.detached(priority: .utility) {
                SystemProbe.treeListeningPorts(root: pid)
            }.value
            // 选端口:优先声明端口;否则局域网可达的;否则第一个
            let chosen = dets.first(where: { $0.port == project.port })
                      ?? dets.first(where: { $0.lan })
                      ?? dets.first
            detectedPort = chosen?.port
            lanReachable = chosen?.lan ?? false
        }

        // 端口首次就绪 → 通知
        if isReady && !wasReady {
            wasReady = true
            Notifier.notify(
                title: project.name,
                zh: "已就绪 · \(browserURL?.absoluteString ?? "")",
                en: "ready · \(browserURL?.absoluteString ?? "")"
            )
        }
    }

    /// 资源超阈值告警(阈值来自 AppSettings，0 = 关闭；带 10% 迟滞避免反复提醒)
    private func checkResourceAlerts() {
        let d = UserDefaults.standard
        let memLimit = d.double(forKey: "settings.memAlertMB")
        let cpuLimit = d.double(forKey: "settings.cpuAlertPct")
        if memLimit > 0, let m = memMB {
            if m > memLimit && !memAlerted {
                memAlerted = true
                Notifier.notify(title: project.name,
                                zh: "内存超过 \(Int(memLimit)) MB(当前 \(Int(m)) MB)",
                                en: "memory over \(Int(memLimit)) MB (now \(Int(m)) MB)")
            } else if m < memLimit * 0.9 { memAlerted = false }
        }
        if cpuLimit > 0, let c = cpu {
            if c > cpuLimit && !cpuAlerted {
                cpuAlerted = true
                Notifier.notify(title: project.name,
                                zh: "CPU 超过 \(Int(cpuLimit))%(当前 \(Int(c))%)",
                                en: "CPU over \(Int(cpuLimit))% (now \(Int(c))%)")
            } else if c < cpuLimit * 0.9 { cpuAlerted = false }
        }
    }

    // MARK: - 日志

    func clearLogs() {
        logs.removeAll()
        logHandle?.truncateFile(atOffset: 0)
    }

    func copyLogs() {
        let text = logs.map(ANSI.strip).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func append(_ text: String) {
        detectURL(in: text)
        writeToFile(text)
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        logs.append(contentsOf: lines)
        if logs.count > maxLogLines {
            logs.removeFirst(logs.count - maxLogLines)
        }
        // 汇入合并日志流(非空行)
        for l in lines where !l.trimmingCharacters(in: .whitespaces).isEmpty {
            manager?.pushMerged(name: project.name, l)
        }
    }

    private func detectURL(in text: String) {
        guard detectedURL == nil else { return }
        let clean = ANSI.strip(text)
        // 匹配 http(s)://localhost:port 或 127.0.0.1:port
        guard let range = clean.range(
            of: #"https?://(localhost|127\.0\.0\.1)(:\d+)?[^\s]*"#,
            options: .regularExpression
        ) else { return }
        detectedURL = String(clean[range])
    }

    // MARK: - 日志落盘（崩溃后可回看）

    private static var logDir: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DevManager/logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private var logFileURL: URL {
        Self.logDir.appendingPathComponent("\(id.uuidString).log")
    }

    private func loadPersistedLogs() {
        let url = logFileURL
        if let data = try? Data(contentsOf: url), let str = String(data: data, encoding: .utf8) {
            let lines = str.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            logs = Array(lines.suffix(maxLogLines))
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        logHandle = try? FileHandle(forWritingTo: url)
        logHandle?.seekToEndOfFile()
    }

    private func writeToFile(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        logHandle?.write(data)
    }
}
