import Foundation
import Network

/// MCP 接入命令（已发布到 npm，用 npx 拉起）
enum MCPInfo {
    static let pkg = "@labtool/devmanager-mcp@latest"
    static var claude: String { "claude mcp add -s user devmanager -- npx --prefer-offline \(pkg)" }
    static var codex: String  { "codex mcp add devmanager -- npx --prefer-offline \(pkg)" }
    static var raw: String    { "npx --prefer-offline \(pkg)" }
}

/// 本地控制服务：绑 127.0.0.1，给 MCP 桥暴露 JSON 接口，让 AI 工具操作进程。
@MainActor
final class ControlServer {
    static let port: UInt16 = 39125
    private var listener: NWListener?
    unowned let manager: ProcessManager

    init(manager: ProcessManager) { self.manager = manager }

    func start() {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let port = NWEndpoint.Port(rawValue: Self.port),
              let l = try? NWListener(using: params, on: port) else {
            NSLog("ControlServer: create failed")
            return
        }
        l.stateUpdateHandler = { state in
            if case .failed(let e) = state { NSLog("ControlServer failed: \(e)") }
        }
        l.newConnectionHandler = { [weak self] conn in
            guard Self.isLoopback(conn) else { conn.cancel(); return }   // 只接受本机回环
            conn.start(queue: .global())
            self?.read(conn, buffer: Data())
        }
        l.start(queue: .global())
        listener = l
    }

    nonisolated static func isLoopback(_ conn: NWConnection) -> Bool {
        guard case let .hostPort(host, _) = conn.endpoint else { return false }
        switch host {
        case .ipv4(let a): return a.isLoopback
        case .ipv6(let a): return a.isLoopback
        case .name(let n, _): return n == "localhost"
        @unknown default: return false
        }
    }

    nonisolated private func read(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { data, _, done, err in
            var buf = buffer
            if let data { buf.append(data) }
            if let req = HTTPRequest.parse(buf) {
                Task { @MainActor in
                    let body = self.route(req)
                    self.respond(conn, json: body)
                }
            } else if err == nil && !done {
                self.read(conn, buffer: buf)
            } else {
                conn.cancel()
            }
        }
    }

    nonisolated private func respond(_ conn: NWConnection, json: String) {
        let body = Data(json.utf8)
        var head = "HTTP/1.1 200 OK\r\n"
        head += "Content-Type: application/json; charset=utf-8\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var out = Data(head.utf8); out.append(body)
        conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
    }

    // MARK: - 路由

    private func route(_ req: HTTPRequest) -> String {
        switch (req.method, req.path) {
        case ("GET", "/health"):
            return json(["ok": true, "app": "DevManager", "version": AppInfo.version])

        case ("GET", "/projects"):
            return jsonArray(manager.processes.map(projectDTO))

        case ("GET", "/profiles"):
            return jsonArray(manager.profiles.map { p in
                [ "id": p.id.uuidString, "name": p.name,
                  "projects": manager.projectsIn(p).map { $0.project.name } ]
            })

        case ("POST", "/start"):
            if let p = target(req) { p.start(); return okState(p) }
            return err("project not found")

        case ("POST", "/stop"):
            if let p = target(req) { p.stop(); return okState(p) }
            return err("project not found")

        case ("POST", "/restart"):
            if let p = target(req) { p.restart(); return okState(p) }
            return err("project not found")

        case ("POST", "/create"):
            return createProject(req)

        case ("POST", "/delete"):
            if let p = target(req) { manager.delete(id: p.id); return json(["ok": true, "deleted": p.project.name]) }
            return err("project not found")

        case ("POST", "/start_profile"):
            if let idStr = req.jsonBody["id"] as? String, let id = UUID(uuidString: idStr),
               let profile = manager.profiles.first(where: { $0.id == id }) {
                manager.startProfile(profile)
                return json(["ok": true])
            }
            return err("profile not found")

        case ("GET", "/logs"):
            guard let idStr = req.query["id"], let id = UUID(uuidString: idStr),
                  let p = manager.process(for: id) else { return err("project not found") }
            let n = Int(req.query["lines"] ?? "200") ?? 200
            let lines = p.logs.suffix(n).map(ANSI.strip)
            return json(["name": p.project.name, "logs": Array(lines)])

        default:
            return err("unknown route \(req.method) \(req.path)")
        }
    }

    private func createProject(_ req: HTTPRequest) -> String {
        let b = req.jsonBody
        guard let path = b["path"] as? String, !path.trimmingCharacters(in: .whitespaces).isEmpty,
              let command = b["command"] as? String, !command.trimmingCharacters(in: .whitespaces).isEmpty
        else { return err("path 和 command 必填") }

        let folder = ((path as NSString).expandingTildeInPath as NSString).lastPathComponent
        let name: String = {
            if let n = b["name"] as? String, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
            return "\(folder)/\(commandSuffix(command))"
        }()
        let port = b["port"] as? Int
        let tags = (b["tags"] as? [String]) ?? []

        let project = Project(name: name, path: path, command: command, port: port, tags: tags)
        let created = manager.addProjects([project])
        guard let mp = created.first else { return err("创建失败") }
        if b["start"] as? Bool == true { mp.start() }
        return json(projectDTO(mp))
    }

    /// "npm run dev" → "dev"；"uvicorn app" → "uvicorn"
    private func commandSuffix(_ command: String) -> String {
        let words = command.split(separator: " ").map(String.init)
        if let i = words.firstIndex(of: "run"), i + 1 < words.count { return words[i + 1] }
        return words.last ?? "dev"
    }

    private func target(_ req: HTTPRequest) -> ManagedProcess? {
        // 支持按 id 或 name 定位
        if let idStr = req.jsonBody["id"] as? String, let id = UUID(uuidString: idStr) {
            return manager.process(for: id)
        }
        if let name = req.jsonBody["name"] as? String {
            return manager.processes.first { $0.project.name == name }
        }
        return nil
    }

    private func projectDTO(_ p: ManagedProcess) -> [String: Any] {
        [ "id": p.id.uuidString,
          "name": p.project.name,
          "path": p.project.path,
          "command": p.project.command,
          "port": p.project.port as Any,
          "tags": p.project.tags,
          "state": stateString(p.phase),
          "ready": p.isReady ]
    }

    private func stateString(_ s: RunState) -> String {
        switch s { case .running: "running"; case .starting: "starting"; case .stopped: "stopped" }
    }

    private func okState(_ p: ManagedProcess) -> String { json(projectDTO(p)) }
    private func err(_ msg: String) -> String { json(["error": msg]) }

    private func json(_ obj: [String: Any]) -> String {
        (try? String(data: JSONSerialization.data(withJSONObject: obj), encoding: .utf8)) ?? "{}"
    }
    private func jsonArray(_ arr: [[String: Any]]) -> String {
        (try? String(data: JSONSerialization.data(withJSONObject: arr), encoding: .utf8)) ?? "[]"
    }
}

// MARK: - 极简 HTTP 请求解析

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let jsonBody: [String: Any]

    static func parse(_ data: Data) -> HTTPRequest? {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data[..<sep.lowerBound]
        guard let headerStr = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerStr.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let rawPath = String(parts[1])

        // Content-Length → 确认 body 完整
        var contentLength = 0
        for line in lines.dropFirst() where line.lowercased().hasPrefix("content-length:") {
            contentLength = Int(line.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        let bodyStart = sep.upperBound
        let available = data.distance(from: bodyStart, to: data.endIndex)
        if available < contentLength { return nil } // body 还没收全

        let bodyData = data[bodyStart..<data.index(bodyStart, offsetBy: contentLength)]
        var jsonBody: [String: Any] = [:]
        if !bodyData.isEmpty,
           let obj = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
            jsonBody = obj
        }

        // path + query
        var path = rawPath, query: [String: String] = [:]
        if let q = rawPath.firstIndex(of: "?") {
            path = String(rawPath[..<q])
            for pair in rawPath[rawPath.index(after: q)...].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    query[String(kv[0])] = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                }
            }
        }
        return HTTPRequest(method: method, path: path, query: query, jsonBody: jsonBody)
    }
}
