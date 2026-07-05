import SwiftUI
import AppKit

/// 设置里的「端口」页：列出本机所有正在监听的端口 + 占用进程，可打开/结束。
struct PortsTab: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ProcessManager.self) private var pm

    @State private var ports: [SystemProbe.ListeningPort] = []
    @State private var ourPids: Set<Int32> = []
    @State private var loading = false
    @State private var confirmKill: SystemProbe.ListeningPort?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.t("ports_title"))
                        .font(.system(.title3, design: .monospaced)).foregroundStyle(Theme.text)
                    Text(settings.t("ports_desc"))
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.textDim)
                }
                Spacer()
                Button { refresh() } label: {
                    Label(settings.t("ports_refresh"), systemImage: "arrow.clockwise")
                        .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.active)
            }

            if ports.isEmpty {
                Text(loading ? settings.t("ports_loading") : settings.t("ports_empty"))
                    .font(.system(.callout, design: .monospaced)).foregroundStyle(Theme.textDim)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 34)
            } else {
                SettingsCard {
                    ForEach(Array(ports.enumerated()), id: \.element.id) { i, p in
                        if i > 0 { Divider().padding(.leading, 16) }
                        row(p)
                    }
                }
                Text("\(ports.count) \(settings.t("ports_count_suffix"))")
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(Theme.textDim)
            }
        }
        .onAppear { refresh() }
        .alert(settings.t("ports_kill_confirm"), isPresented: Binding(
            get: { confirmKill != nil },
            set: { if !$0 { confirmKill = nil } }
        )) {
            Button(settings.t("cancel"), role: .cancel) { confirmKill = nil }
            Button(settings.t("ports_kill"), role: .destructive) {
                if let p = confirmKill {
                    SystemProbe.terminate(pid: p.pid)
                    confirmKill = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { refresh() }
                }
            }
        } message: {
            if let p = confirmKill {
                Text(":\(p.port) · \(p.command) (PID \(p.pid))")
            }
        }
    }

    private func row(_ p: SystemProbe.ListeningPort) -> some View {
        let ours = ourPids.contains(p.pid)
        return HStack(spacing: 12) {
            Text(":\(p.port)")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(ours ? Theme.active : Theme.text)
                .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(p.command)
                        .font(.system(.callout, design: .monospaced)).foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if ours {
                        Text(settings.t("ports_managed"))
                            .font(.system(.caption2, design: .monospaced)).foregroundStyle(Theme.active)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.activeBg))
                    }
                }
                Text("PID \(p.pid) · \(p.addr)")
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(Theme.textDim)
            }

            Spacer(minLength: 8)

            Button { openBrowser(p.port) } label: {
                Image(systemName: "safari").font(.system(size: 13))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.textDim)
            .help(settings.t("ports_open"))

            Button { confirmKill = p } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 15))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.stopped)
            .help(settings.t("ports_kill"))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func refresh() {
        loading = true
        // 本应用正在运行的项目的进程树 pid（用来标记"本应用管理"的端口）
        let roots = pm.processes.compactMap { $0.state == .running ? $0.rootPID : nil }
        Task.detached {
            let list = SystemProbe.listeningPorts()
            var ours = Set<Int32>()
            for r in roots { ours.formUnion(SystemProbe.descendants(of: r)) }
            await MainActor.run {
                ports = list
                ourPids = ours
                loading = false
            }
        }
    }

    private func openBrowser(_ port: Int) {
        if let url = URL(string: "http://localhost:\(port)") { NSWorkspace.shared.open(url) }
    }
}
