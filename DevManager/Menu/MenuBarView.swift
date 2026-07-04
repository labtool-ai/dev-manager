import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部
            HStack(spacing: 5) {
                Text("\(manager.runningCount)")
                    .fontWeight(.semibold)
                    .foregroundStyle(manager.runningCount > 0 ? Theme.active : Color.secondary)
                Text(settings.t("running"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(manager.processes.count) \(settings.t("projects"))")
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // 项目（按 tag 分组）
            ForEach(manager.grouped, id: \.tag) { group in
                Text(group.tag.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 2)

                ForEach(group.items) { proc in
                    MenuRow(proc: proc)
                }
            }

            Divider().padding(.horizontal, 12).padding(.vertical, 6)

            MenuActionRow(title: settings.t("open_devmanager"), systemImage: "macwindow") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            MenuActionRow(title: settings.t("quit_devmanager"), systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(.bottom, 6)
        .frame(width: 268)
        .background(VisualEffectView(material: .menu))
    }
}

// MARK: - 项目行（整行悬停高亮，点按启停）

private struct MenuRow: View {
    let proc: ManagedProcess
    @State private var hover = false

    var body: some View {
        Button {
            proc.toggle()
        } label: {
            HStack(spacing: 8) {
                StatusDot(state: proc.phase)
                Text(proc.project.name)
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if let port = proc.project.port {
                    Text(":\(port)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: proc.state == .stopped ? "play.fill" : "stop.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(hover ? Theme.active : .secondary)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hover ? Theme.activeBg : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { hover = $0 }
    }
}

// MARK: - 底部菜单项

private struct MenuActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(hover ? Theme.active : .secondary)
                Text(title)
                    .foregroundStyle(Color(nsColor: .labelColor))
                Spacer()
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hover ? Theme.activeBg : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { hover = $0 }
    }
}

// MARK: - 原生毛玻璃材质

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .menu

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
