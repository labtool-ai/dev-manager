import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    private var zh: Bool { settings.resolvedLanguage == .zh }

    /// 菜单栏只列运行中的项目(按 tag 分组，空组丢掉)
    private var runningGroups: [(tag: String, items: [ManagedProcess])] {
        manager.grouped.compactMap { g in
            let items = g.items.filter { $0.state != .stopped }
            return items.isEmpty ? nil : (tag: g.tag, items: items)
        }
    }

    private var listMaxHeight: CGFloat {
        min(400, (NSScreen.main?.visibleFrame.height ?? 800) - 140)
    }

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

            // 运行中的项目（按 tag 分组，超出内部滚动）
            if runningGroups.isEmpty {
                Text(zh ? "没有运行中的项目" : "Nothing running")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(runningGroups, id: \.tag) { group in
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
                    }
                    .padding(.bottom, 2)
                }
                .scrollContentBackground(.hidden)
                .frame(maxHeight: listMaxHeight)
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
        // 背景由承载它的 NSPanel 的 NSVisualEffectView contentView 提供(见 StatusItemController)
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
        .buttonStyle(.hit)
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
        .buttonStyle(.hit)
        .padding(.horizontal, 6)
        .onHover { hover = $0 }
    }
}

