import SwiftUI
import AppKit

/// 合并日志流：所有运行中项目的输出汇到一个视图，每行带项目名(彩色区分)。
struct MergedLogView: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @State private var filter = ""

    private var zh: Bool { settings.resolvedLanguage == .zh }

    private var rows: [ProcessManager.MergedLine] {
        guard !filter.isEmpty else { return manager.mergedLog }
        return manager.mergedLog.filter {
            ANSI.strip($0.line).localizedCaseInsensitiveContains(filter)
            || $0.name.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(zh ? "合并日志" : "Merged logs")
                    .font(.system(.title, design: .monospaced)).bold()
                    .foregroundStyle(Theme.text)
                Text(zh ? "\(manager.runningCount) 个运行中" : "\(manager.runningCount) running")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
                Spacer()
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.caption2).foregroundStyle(Theme.textDim)
                    TextField(zh ? "过滤（项目名 / 内容）" : "filter (name / text)", text: $filter)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))

                Button { manager.clearMerged() } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .buttonStyle(.hit).foregroundStyle(Theme.textDim).help(zh ? "清空" : "clear")
            }

            logList
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: 10) {
                            Text(row.name)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(TagStyle.color(for: row.name))
                                .frame(width: 150, alignment: .leading)
                                .lineLimit(1)
                            Text(ANSI.attributed(row.line.isEmpty ? " " : row.line))
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .id(row.id)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
            .onChange(of: manager.mergedLog.count) { _, _ in
                if filter.isEmpty, let last = rows.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }
}
