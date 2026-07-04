import SwiftUI

/// ⌘K 快速启动面板：搜项目 → ↑↓ 选择 → 回车启停 → esc 关闭。
struct CommandPalette: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Binding var selection: UUID?

    @State private var query = ""
    @State private var index = 0
    @FocusState private var focused: Bool

    private var results: [ManagedProcess] {
        let all = manager.processes
        guard !query.isEmpty else { return all }
        return all.filter { fuzzy(query, $0.project.name) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textDim)
                TextField(settings.resolvedLanguage == .zh ? "搜索项目、回车启停…" : "Search projects, enter to toggle…",
                          text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .focused($focused)
                    .onChange(of: query) { _, _ in index = 0 }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider()

            // 结果
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { i, proc in
                            row(proc, selected: i == index)
                                .id(i)
                                .contentShape(Rectangle())
                                .onTapGesture { activate(proc) }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 320)
                .onChange(of: index) { _, i in
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(i, anchor: .center) }
                }
            }
        }
        .frame(width: 540)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border))
        .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
        .onAppear { focused = true; index = 0 }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.return) { if results.indices.contains(index) { activate(results[index]) }; return .handled }
        .onKeyPress(.escape) { settings.showPalette = false; return .handled }
    }

    private func row(_ proc: ManagedProcess, selected: Bool) -> some View {
        HStack(spacing: 10) {
            StatusDot(state: proc.phase)
            Text(proc.project.name)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            if let tag = proc.project.tags.first {
                Text(tag)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
            if let port = proc.project.port {
                Text(":\(port)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
            }
            Text(proc.state == .stopped ? (settings.resolvedLanguage == .zh ? "启动" : "start")
                                        : (settings.resolvedLanguage == .zh ? "停止" : "stop"))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textDim)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Theme.active.opacity(0.16) : .clear)
        )
    }

    private func move(_ d: Int) {
        guard !results.isEmpty else { return }
        index = min(max(0, index + d), results.count - 1)
    }

    private func activate(_ proc: ManagedProcess) {
        selection = proc.id
        proc.toggle()
        settings.showPalette = false
    }

    /// 简单模糊匹配:query 的字符按序出现在 name 里即可
    private func fuzzy(_ query: String, _ name: String) -> Bool {
        let q = Array(query.lowercased())
        let n = Array(name.lowercased())
        var qi = 0
        for ch in n where qi < q.count && ch == q[qi] { qi += 1 }
        return qi == q.count
    }
}
