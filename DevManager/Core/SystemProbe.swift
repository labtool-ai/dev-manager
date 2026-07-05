import Foundation

/// 系统探测：端口是否就绪、进程树的 CPU/内存。全部 nonisolated，供后台采样调用。
enum SystemProbe {

    /// TCP 连一下 127.0.0.1:port，能连上即视为就绪
    static func isPortOpen(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        // 设个短超时，避免个别情况阻塞
        var tv = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port)).bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    /// 采样一棵进程树（root + 所有后代）的 CPU% 之和与内存 MB 之和
    static func sampleTree(root: Int32) -> (cpu: Double, memMB: Double)? {
        guard let out = run("/bin/ps", ["-axo", "pid=,ppid=,%cpu=,rss="]) else { return nil }

        var children: [Int32: [Int32]] = [:]
        var cpuOf: [Int32: Double] = [:]
        var rssOf: [Int32: Double] = [:]   // KB

        for line in out.split(separator: "\n") {
            let f = line.split(whereSeparator: { $0 == " " }).map(String.init)
            guard f.count >= 4,
                  let pid = Int32(f[0]), let ppid = Int32(f[1]),
                  let cpu = Double(f[2]), let rss = Double(f[3]) else { continue }
            children[ppid, default: []].append(pid)
            cpuOf[pid] = cpu
            rssOf[pid] = rss
        }

        // BFS 收集 root 及其后代
        var totalCPU = 0.0, totalRSS = 0.0
        var queue = [root]
        var seen = Set<Int32>()
        while let pid = queue.popLast() {
            guard seen.insert(pid).inserted else { continue }
            totalCPU += cpuOf[pid] ?? 0
            totalRSS += rssOf[pid] ?? 0
            queue.append(contentsOf: children[pid] ?? [])
        }
        return (totalCPU, totalRSS / 1024.0)
    }

    /// 谁在监听这个端口：返回占用者 pid + 进程名(command)
    static func portOccupier(_ port: Int) -> (pid: Int32, name: String)? {
        guard let out = run("/usr/sbin/lsof",
                            ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-Fpc"]) else { return nil }
        // -F 输出：p<pid> 行、c<command> 行
        var pid: Int32?
        var cmd = ""
        for line in out.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("p") { pid = Int32(s.dropFirst()) }
            else if s.hasPrefix("c") { cmd = String(s.dropFirst()) }
        }
        if let pid { return (pid, cmd.isEmpty ? "未知进程" : cmd) }
        return nil
    }

    /// 某 root 进程的整棵子树 pid 集合(含 root)—— 判断占用者是不是我们自己拉起的
    static func descendants(of root: Int32) -> Set<Int32> {
        guard let out = run("/bin/ps", ["-axo", "pid=,ppid="]) else { return [root] }
        var children: [Int32: [Int32]] = [:]
        for line in out.split(separator: "\n") {
            let f = line.split(whereSeparator: { $0 == " " }).map(String.init)
            guard f.count >= 2, let pid = Int32(f[0]), let ppid = Int32(f[1]) else { continue }
            children[ppid, default: []].append(pid)
        }
        var result = Set<Int32>()
        var queue = [root]
        while let pid = queue.popLast() {
            guard result.insert(pid).inserted else { continue }
            queue.append(contentsOf: children[pid] ?? [])
        }
        return result
    }

    /// 本机局域网 IPv4(en0/en1),给"手机同网测试"用
    static func localIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var result: String?
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
                  let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name == "en0" || name == "en1" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                        &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: host)
            if !ip.isEmpty { result = ip; if name == "en0" { break } }
        }
        return result
    }

    /// 一个正在监听的端口 + 占用进程
    struct ListeningPort: Identifiable, Hashable {
        let port: Int
        let pid: Int32
        let command: String
        let addr: String        // 127.0.0.1 / *（所有网卡）/ [::1] 等
        var id: String { "\(port)-\(pid)-\(addr)" }
    }

    /// 列出本机所有正在监听的 TCP 端口 + 占用进程(command / pid / 地址)
    static func listeningPorts() -> [ListeningPort] {
        guard let out = run("/usr/sbin/lsof",
                            ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]) else { return [] }
        // -F 输出按进程分组：p<pid> / c<command> / n<addr:port>（每个监听 socket 一行 n）
        var list: [ListeningPort] = []
        var pid: Int32 = 0
        var cmd = ""
        for raw in out.split(separator: "\n") {
            let s = String(raw)
            guard let tag = s.first else { continue }
            let v = String(s.dropFirst())
            switch tag {
            case "p": pid = Int32(v) ?? 0
            case "c": cmd = v
            case "n":
                guard let c = v.lastIndex(of: ":"),
                      let port = Int(v[v.index(after: c)...]) else { continue }
                list.append(ListeningPort(port: port, pid: pid, command: cmd, addr: String(v[..<c])))
            default: break
            }
        }
        // 去重(同端口 IPv4/IPv6 可能各一条)+ 按端口、pid 排序
        var seen = Set<String>()
        return list.filter { seen.insert($0.id).inserted }
            .sorted { $0.port != $1.port ? $0.port < $1.port : $0.pid < $1.pid }
    }

    /// 某进程树(root+后代)实际监听的端口 + 是否绑到 0.0.0.0/*(=局域网可达)。
    /// 用来:没声明端口时自动探端口;判断二维码是否真能被局域网设备访问。
    static func treeListeningPorts(root: Int32) -> [(port: Int, lan: Bool)] {
        let pids = descendants(of: root)
        guard !pids.isEmpty else { return [] }
        let pidArg = pids.map(String.init).joined(separator: ",")
        guard let out = run("/usr/sbin/lsof",
                            ["-nP", "-iTCP", "-sTCP:LISTEN", "-a", "-p", pidArg, "-Fn"]) else { return [] }
        var lanByPort: [Int: Bool] = [:]   // 同端口 IPv4/IPv6 合并:任一绑到 * 即视为局域网可达
        for line in out.split(separator: "\n") {
            let s = String(line); guard s.hasPrefix("n") else { continue }
            let v = String(s.dropFirst())
            guard let c = v.lastIndex(of: ":"), let port = Int(v[v.index(after: c)...]) else { continue }
            let addr = String(v[..<c])
            let lan = (addr == "*" || addr == "0.0.0.0" || addr == "[::]" || addr == "::")
            lanByPort[port] = (lanByPort[port] ?? false) || lan
        }
        return lanByPort.map { (port: $0.key, lan: $0.value) }.sorted { $0.port < $1.port }
    }

    /// 结束某个进程（先 SIGTERM）
    static func terminate(pid: Int32) { kill(pid, SIGTERM) }

    private static func run(_ launchPath: String, _ args: [String]) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
