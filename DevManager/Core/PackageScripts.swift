import Foundation

/// 读取文件夹里的 package.json,列出 scripts,并识别包管理器。
enum PackageScripts {
    struct Detected {
        let manager: String                       // npm / pnpm / yarn / bun
        let scripts: [(name: String, command: String)]
    }

    static func detect(atFolder path: String) -> Detected? {
        let dir = (path as NSString).expandingTildeInPath
        guard !dir.isEmpty else { return nil }
        let pkgURL = URL(fileURLWithPath: dir).appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: pkgURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: String],
              !scripts.isEmpty else { return nil }

        let fm = FileManager.default
        let pm: String
        if fm.fileExists(atPath: dir + "/pnpm-lock.yaml") { pm = "pnpm" }
        else if fm.fileExists(atPath: dir + "/yarn.lock") { pm = "yarn" }
        else if fm.fileExists(atPath: dir + "/bun.lockb") { pm = "bun" }
        else { pm = "npm" }

        // 常用脚本排前面
        let order = ["dev", "start", "serve", "preview", "build", "test", "lint"]
        let names = scripts.keys.sorted { a, b in
            let ia = order.firstIndex(of: a) ?? Int.max
            let ib = order.firstIndex(of: b) ?? Int.max
            return ia != ib ? ia < ib : a < b
        }
        let cmds = names.map { name -> (String, String) in
            let run = pm == "yarn" ? "yarn \(name)" : "\(pm) run \(name)"
            return (name, run)
        }
        return Detected(manager: pm, scripts: cmds)
    }
}
