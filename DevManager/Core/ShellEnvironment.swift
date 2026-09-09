import Foundation

/// GUI 应用从 Finder/Dock 启动时 PATH 是极简的(/usr/bin:/bin:/usr/sbin:/sbin),
/// 而 nvm / fnm / volta / conda 这类通常在 ~/.zshrc 里初始化 ——
/// 但我们用 `zsh -lc`(登录但**非交互**)跑命令,zsh 不读 .zshrc,
/// 于是 pnpm / node 这类命令直接 "command not found"(退出码 127)。
///
/// 这里用一次**交互式登录 shell** 把真实 PATH 解析出来并缓存,注入到子进程。
/// 只解析一次:既拿到完整 PATH,又不必每次启动都执行 .zshrc(避免慢 + 日志噪音)。
enum ShellEnvironment {
    private static let sentinel = "__DEVMANAGER_PATH__"
    private static var cached: String?

    /// 供子进程使用的 PATH(解析失败则退回当前进程的 PATH)
    static var loginPATH: String {
        if let cached { return cached }
        let value = resolve() ?? ProcessInfo.processInfo.environment["PATH"]
            ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        cached = value
        return value
    }

    /// 提前预热(app 启动时后台调用),避免首次启动项目时卡一下
    static func warmUp() {
        DispatchQueue.global(qos: .utility).async { _ = loginPATH }
    }

    private static func resolve() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // 用哨兵行输出，避免 .zshrc 自身的输出(p10k 提示等)混进来
        proc.arguments = ["-ilc", "printf '\\n\(sentinel)%s\\n' \"$PATH\""]
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"          // 抑制 powerlevel10k 之类的即时提示
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let out = String(data: data, encoding: .utf8) else { return nil }
            for line in out.split(separator: "\n") where line.hasPrefix(sentinel) {
                let path = String(line.dropFirst(sentinel.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty { return path }
            }
            return nil
        } catch {
            return nil
        }
    }
}
