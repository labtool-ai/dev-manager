import SwiftUI
import AppKit

struct SidebarView: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Binding var selection: UUID?

    @State private var collapsed: Set<String> = []
    @State private var hoveredRow: UUID?
    @State private var search = ""
    @State private var editingProfile: Profile?
    @State private var editingProject: Project?
    @State private var pendingDelete: ManagedProcess?

    /// 按搜索过滤后的分组
    private var groups: [(tag: String, items: [ManagedProcess])] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return manager.grouped }
        return manager.grouped.compactMap { g in
            let items = g.items.filter {
                $0.project.name.lowercased().contains(q) || g.tag.lowercased().contains(q)
            }
            return items.isEmpty ? nil : (tag: g.tag, items: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2).foregroundStyle(Theme.textDim)
                TextField(settings.resolvedLanguage == .zh ? "搜索项目 / 标签" : "search projects / tags",
                          text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption2)
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.textDim)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
            .padding(.horizontal, 10)
            .padding(.top, 10)

            // 自控滚动列表：不用 List，避免 NSTableView 在 resize 时顶部 inset 漂移
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Profiles（启动组合）
                    if search.isEmpty {
                        HStack(spacing: 6) {
                            Text("PROFILES")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.textDim)
                            Spacer()
                            Button { editingProfile = Profile() } label: {
                                Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                            }
                            .buttonStyle(.plain).foregroundStyle(Theme.textDim)
                            .help(settings.resolvedLanguage == .zh ? "新建启动组合" : "New profile")
                        }
                        .padding(.horizontal, 12).padding(.top, 4)

                        ForEach(manager.profiles) { profile in
                            ProfileRow(profile: profile,
                                       count: manager.projectsIn(profile).count,
                                       onRun: { manager.startProfile(profile) },
                                       onEdit: { editingProfile = profile })
                                .padding(.horizontal, 6)
                        }

                        Color.clear.frame(height: 8)
                    }

                    ForEach(groups, id: \.tag) { group in
                        GroupHeader(
                            tag: group.tag,
                            isCollapsed: collapsed.contains(group.tag),
                            toggle: { toggle(group.tag) }
                        )
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                        if !collapsed.contains(group.tag) {
                            ForEach(group.items) { proc in
                                SidebarRow(
                                    proc: proc,
                                    isSelected: selection == proc.id,
                                    hovered: hoveredRow == proc.id
                                )
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { editingProject = proc.project }
                                .onTapGesture { selection = proc.id }
                                .contextMenu {
                                    Button(proc.state == .stopped ? "启动" : "停止",
                                           systemImage: proc.state == .stopped ? "play.fill" : "stop.fill") {
                                        proc.toggle()
                                    }
                                    if proc.state != .stopped {
                                        Button("重启", systemImage: "arrow.clockwise") { proc.restart() }
                                    }
                                    Divider()
                                    Button("重命名 / 编辑…", systemImage: "pencil") { editingProject = proc.project }
                                    Button("在 Finder 中显示", systemImage: "folder") {
                                        NSWorkspace.shared.selectFile(
                                            nil,
                                            inFileViewerRootedAtPath: (proc.project.path as NSString).expandingTildeInPath
                                        )
                                    }
                                    Divider()
                                    Button("删除…", systemImage: "trash", role: .destructive) { pendingDelete = proc }
                                }
                                .onHover { hoveredRow = $0 ? proc.id : (hoveredRow == proc.id ? nil : hoveredRow) }
                                .draggable(proc.id.uuidString)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let s = items.first, let id = UUID(uuidString: s) else { return false }
                                    manager.moveToTag(id, tag: group.tag)   // 跨组拖 → 改到目标分组
                                    manager.move(id, before: proc.id)       // 再在组内定位
                                    return true
                                }
                                .padding(.horizontal, 6)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 48)   // 给悬浮胶囊留出空间，末行不被盖
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 左下角悬浮状态胶囊（原生侧栏圆角保持不变）
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 5) {
                Text("\(manager.runningCount) \(settings.t("running"))")
                    .foregroundStyle(Theme.active)
                Text("/ \(manager.processes.count) \(settings.t("projects"))")
                    .foregroundStyle(Theme.textDim)
            }
            .font(.system(.caption2, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.surface, in: Capsule())
            .shadow(color: .black.opacity(0.14), radius: 6, y: 2)
            .padding(12)
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorSheet(profile: profile, all: manager.processes)
                .environment(manager)
                .environment(settings)
        }
        .sheet(item: $editingProject) { project in
            EditProjectSheet(project: project)
                .environment(manager)
                .environment(settings)
        }
        .confirmationDialog("删除项目", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { p in
            Button("删除「\(p.project.name)」", role: .destructive) {
                if selection == p.id { selection = nil }
                manager.delete(id: p.id)
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { p in
            Text("将从列表中移除「\(p.project.name)」(不会删除磁盘上的文件)。")
        }
    }

    private func toggle(_ tag: String) {
        if collapsed.contains(tag) { collapsed.remove(tag) } else { collapsed.insert(tag) }
    }
}

// MARK: - Profile 行（hover 显示 ▶ 启动 / 编辑）

private struct ProfileRow: View {
    let profile: Profile
    let count: Int
    let onRun: () -> Void
    let onEdit: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textDim)
            Text(profile.name)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text("\(count)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textDim)
            Spacer(minLength: 4)
            if hovered {
                Button(action: onRun) {
                    Image(systemName: "play.fill").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.active)
                .help("启动整个组合")
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.textDim)
            }
        }
        .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovered ? Theme.textDim.opacity(0.10) : .clear))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onEdit() }
        .onHover { hovered = $0 }
    }
}

// MARK: - 分组标题：可折叠 + hover 显示整组操作

private struct GroupHeader: View {
    @Environment(ProcessManager.self) private var manager
    let tag: String
    let isCollapsed: Bool
    let toggle: () -> Void

    @State private var hovered = false
    @State private var renaming = false
    @State private var draft = ""
    @State private var dropTargeted = false

    private var running: Int { manager.runningCount(inTag: tag) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textDim)
                .rotationEffect(.degrees(isCollapsed ? 0 : 90))

            TagIcon(tag: tag, size: 18)

            Text(tag)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.text)

            if running > 0 {
                Text("\(running)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.active)
            }

            Spacer(minLength: 4)

            if hovered {
                Button { manager.startTag(tag) } label: {
                    Image(systemName: "play.fill").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.active)
                .help("启动整组")

                Menu {
                    Button("启动整组", systemImage: "play.fill") { manager.startTag(tag) }
                    Button("停止整组", systemImage: "stop.fill") { manager.stopTag(tag) }
                    Divider()
                    Button("重命名分组…", systemImage: "pencil") { draft = tag; renaming = true }
                    Divider()
                    Button(isCollapsed ? "展开" : "折叠",
                           systemImage: isCollapsed ? "chevron.down" : "chevron.right") { toggle() }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 10))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(Theme.textDim)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(dropTargeted ? Theme.active.opacity(0.18) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .onHover { hovered = $0 }
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first, let id = UUID(uuidString: s) else { return false }
            manager.moveToTag(id, tag: tag)     // 拖到分组标题 → 并入该分组
            return true
        } isTargeted: { dropTargeted = $0 }
        .contextMenu {
            Button("启动整组", systemImage: "play.fill") { manager.startTag(tag) }
            Button("停止整组", systemImage: "stop.fill") { manager.stopTag(tag) }
            Divider()
            Button("重命名分组…", systemImage: "pencil") { draft = tag; renaming = true }
        }
        .alert("重命名分组", isPresented: $renaming) {
            TextField("分组名", text: $draft)
            Button("保存") { manager.renameTag(from: tag, to: draft) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将这组下所有项目的分组名改为新名字。")
        }
    }
}

// MARK: - 项目行：自绘选中 / 悬停（中性灰）

private struct SidebarRow: View {
    let proc: ManagedProcess
    let isSelected: Bool
    let hovered: Bool

    private var rowFill: Color {
        if isSelected { return Theme.active.opacity(0.16) }
        if hovered { return Theme.textDim.opacity(0.10) }
        return .clear
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(state: proc.phase)
            Text(proc.project.name)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let port = proc.project.port {
                Text(":\(port)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(proc.isReady ? Theme.text : Theme.textDim)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(rowFill))
    }
}
