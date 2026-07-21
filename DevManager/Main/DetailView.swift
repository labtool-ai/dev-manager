import SwiftUI
import AppKit

struct DetailView: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    let proc: ManagedProcess
    @Binding var selection: UUID?

    @State private var showLogs = true
    @State private var showingEdit = false
    @State private var addingTag = false
    @State private var newTag = ""
    @State private var logSearch = ""
    @FocusState private var logSearchFocused: Bool
    @State private var conflict: ProcessManager.PortConflict?

    private var stateLabel: String {
        switch proc.phase {
        case .running:  settings.t("state_running")
        case .starting: settings.t("state_starting")
        case .stopped:  settings.t("state_stopped")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 顶部：左信息 + 右局域网面板(运行且有端口时内联展示)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    tagsRow
                    infoBlock
                    if proc.state == .running { metricsRow }
                    actionRow
                }
                Spacer(minLength: 0)
                if proc.state == .running, let port = proc.effectivePort {
                    if proc.lanReachable {
                        NetworkShareView(port: port)
                            .environment(settings)
                            .fixedSize()
                    } else {
                        LocalOnlyHint(port: port)
                            .environment(settings)
                            .fixedSize()
                    }
                }
            }

            if showLogs {
                logSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(EdgeInsets(top: 24, leading: 24, bottom: 16, trailing: 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showingEdit) {
            EditProjectSheet(project: proc.project)
                .environment(manager)
                .environment(settings)
        }
        .confirmationDialog(conflictTitle, isPresented: Binding(
            get: { conflict != nil },
            set: { if !$0 { conflict = nil } }
        ), presenting: conflict) { c in
            // 结束占用者并启动
            Button(conflictConfirmLabel(c), role: isExternal(c) ? .destructive : nil) {
                manager.resolveAndStart(c, target: proc)
                conflict = nil
            }
            // 跳到占用它的项目(仅当占用者是本应用的另一个项目)
            if case .ours(_, let occ) = c {
                Button(settings.resolvedLanguage == .zh
                       ? "查看「\(occ.project.name)」" : "Reveal “\(occ.project.name)”") {
                    selection = occ.id
                    conflict = nil
                }
            }
            // 仍然启动:不理会冲突,交给 dev server 自己的端口回退(vite/next 占用会自动 +1)
            Button(settings.resolvedLanguage == .zh ? "仍然启动" : "Start anyway") {
                proc.start()
                conflict = nil
            }
            Button(settings.t("cancel"), role: .cancel) { conflict = nil }
        } message: { c in
            Text(conflictMessage(c))
        }
    }

    // MARK: - 标题

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(proc.project.name)
                .font(.system(.title, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)
            HStack(spacing: 6) {
                StatusDot(state: proc.phase)
                Text(stateLabel)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
                if let port = proc.effectivePort {
                    Button {
                        proc.openInBrowser()
                    } label: {
                        Text(":\(port)")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(proc.isReady ? Theme.text : Theme.textDim)
                            .underline(proc.isReady)
                    }
                    .buttonStyle(.plain)
                    .disabled(!proc.isReady)
                    .help(proc.isReady ? "在浏览器打开 \(proc.browserURL?.absoluteString ?? "")" : "端口未就绪")
                }
            }
        }
    }

    // MARK: - 标签行

    private var tagsRow: some View {
        HStack(spacing: 8) {
            ForEach(proc.project.tags, id: \.self) { tag in
                TagChip(text: tag)
                    .onTapGesture { manager.removeTag(tag, from: proc.id) }
                    .help("点按移除")
            }

            if addingTag {
                TextField("tag", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(width: 90)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.border))
                    .onSubmit { commitTag() }
            } else {
                Button { addingTag = true } label: {
                    Label("tag", systemImage: "plus")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [3])))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commitTag() {
        manager.addTag(newTag, to: proc.id)
        newTag = ""
        addingTag = false
    }

    // MARK: - path / cmd

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(key: "path", value: proc.project.path)
            InfoRow(key: "cmd", value: proc.project.command)
        }
    }

    // MARK: - 资源行

    private var metricsRow: some View {
        HStack(spacing: 14) {
            metric("cpu", proc.cpu.map { String(format: "%.0f%%", $0) } ?? "—")
            if proc.cpuHistory.count >= 2 {
                Sparkline(data: proc.cpuHistory).frame(width: 54, height: 16)
            }
            metric("mem", proc.memMB.map { String(format: "%.0f MB", $0) } ?? "—")
            if proc.memHistory.count >= 2 {
                Sparkline(data: proc.memHistory).frame(width: 54, height: 16)
            }
            metric("uptime", proc.uptime ?? "—")
            if proc.project.autoRestart {
                Label("auto-restart", systemImage: "arrow.clockwise")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
        }
    }

    private func metric(_ key: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(key).foregroundStyle(Theme.textDim)
            Text(value).foregroundStyle(Theme.text)
        }
        .font(.system(.caption, design: .monospaced))
    }

    // MARK: - 操作行

    private var actionRow: some View {
        // 宽度够 → 图标+文字；不够 → 只显示图标（带 tooltip）；再不够 → 流式换行
        ViewThatFits(in: .horizontal) {
            actionButtons(labeled: true)
            actionButtons(labeled: false)
            FlowLayout(spacing: 8, lineSpacing: 8) { actionButtonList(labeled: false) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButtons(labeled: Bool) -> some View {
        HStack(spacing: 8) { actionButtonList(labeled: labeled) }
    }

    @ViewBuilder
    private func actionButtonList(labeled: Bool) -> some View {
        actionButton(proc.state == .stopped ? "start" : "stop",
                     proc.state == .stopped ? "play.fill" : "stop.fill",
                     tint: Theme.active,
                     labeled: labeled,
                     filled: proc.state != .stopped) { attemptToggle() }   // 运行后实心反相(黑底白图标)
        actionButton("restart", "arrow.clockwise", tint: Theme.textDim, labeled: labeled) { proc.restart() }
        actionButton("logs", "terminal", tint: showLogs ? Theme.active : Theme.textDim, labeled: labeled) { showLogs.toggle() }
        actionButton("edit", "chevron.left.forwardslash.chevron.right", tint: Theme.textDim, labeled: labeled) { showingEdit = true }
        actionButton("finder", "folder", tint: Theme.textDim, labeled: labeled) { revealInFinder() }
        actionButton("delete", "trash", tint: Theme.stopped, labeled: labeled) {
            let id = proc.id
            manager.delete(id: id)
            if selection == id { selection = nil }
        }
    }

    private func actionButton(_ title: String, _ icon: String, tint: Color,
                              labeled: Bool, filled: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if labeled {
                Label(title, systemImage: icon)
            } else {
                Image(systemName: icon)
            }
        }
        .buttonStyle(GhostButtonStyle(tint: tint, filled: filled))
        .help(title)
    }

    // MARK: - 日志区（工具条 + 内容）

    private var logSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2).foregroundStyle(Theme.textDim)
                    TextField(settings.t("filter_logs"), text: $logSearch)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .focused($logSearchFocused)
                    if !logSearch.isEmpty {
                        Button { logSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill").font(.caption2)
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.textDim)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(logSearchFocused ? Theme.active : Theme.border))
                // ⌘F 聚焦日志搜索框(隐藏按钮承载快捷键)
                .background(
                    Button("") { logSearchFocused = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .opacity(0)
                )

                Button { proc.copyLogs() } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(Theme.textDim).help("复制日志")

                Button { proc.clearLogs() } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(Theme.textDim).help("清空日志")
            }

            LogViewer(logs: proc.logs, filter: logSearch)
        }
    }

    // MARK: - 启停(带端口冲突检查)

    private func attemptToggle() {
        if proc.state != .stopped {
            proc.stop()
            return
        }
        Task {
            if let c = await manager.portConflict(for: proc) {
                conflict = c
            } else {
                proc.start()
            }
        }
    }

    private var conflictTitle: String {
        settings.resolvedLanguage == .zh ? "端口被占用" : "Port in use"
    }

    private func isExternal(_ c: ProcessManager.PortConflict) -> Bool {
        if case .external = c { return true }
        return false
    }

    private func conflictMessage(_ c: ProcessManager.PortConflict) -> String {
        let zh = settings.resolvedLanguage == .zh
        switch c {
        case .ours(let port, let occ):
            return zh ? "端口 \(port) 正被本应用的项目「\(occ.project.name)」占用。要停止它再启动吗？"
                      : "Port \(port) is used by this app's project “\(occ.project.name)”. Stop it and start?"
        case .external(let port, let pid, let name):
            return zh ? "端口 \(port) 正被外部进程 \(name)（PID \(pid)）占用。"
                      : "Port \(port) is held by external process \(name) (PID \(pid))."
        }
    }

    private func conflictConfirmLabel(_ c: ProcessManager.PortConflict) -> String {
        let zh = settings.resolvedLanguage == .zh
        switch c {
        case .ours(_, let occ):
            return zh ? "停止「\(occ.project.name)」并启动" : "Stop “\(occ.project.name)” & start"
        case .external:
            return zh ? "停止占用进程并启动" : "Stop it & start"
        }
    }

    private func revealInFinder() {
        let expanded = (proc.project.path as NSString).expandingTildeInPath
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expanded)
    }

}

/// path / cmd 一行:值可选中 + 悬停即可一键复制(复制后短暂显示对勾)。
private struct InfoRow: View {
    let key: String
    let value: String
    @State private var copied = false
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Theme.textDim)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
            Button(action: copy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(copied ? Theme.active : Theme.textDim)
            .opacity(copied || hovering ? 1 : 0.35)
            .help("复制")
        }
        .onHover { hovering = $0 }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            copied = false
        }
    }
}

// MARK: - 日志窗格（ANSI 上色 + 过滤 + 自动滚底）

private struct LogViewer: View {
    let logs: [String]
    let filter: String

    private var rows: [(idx: Int, line: String)] {
        let indexed = Array(logs.enumerated()).map { (idx: $0.offset, line: $0.element) }
        guard !filter.isEmpty else { return indexed }
        return indexed.filter { ANSI.strip($0.line).localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(rows, id: \.idx) { row in
                        Text(ANSI.attributed(row.line.isEmpty ? " " : row.line))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(row.idx)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
            .onChange(of: logs.count) { _, _ in
                guard filter.isEmpty, let last = rows.last?.idx else { return }
                withAnimation { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }
}
