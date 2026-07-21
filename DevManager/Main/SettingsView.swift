import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    var onBack: (() -> Void)? = nil
    @State private var tab: Tab = .display

    enum Tab: String, CaseIterable { case display, general, ports, mcp, stats, updates, about }

    private func tabTitle(_ t: Tab) -> String {
        switch t {
        case .display: settings.t("tab_display")
        case .general: settings.t("tab_general")
        case .ports:   settings.t("tab_ports")
        case .mcp:     "MCP"
        case .stats:   settings.t("tab_stats")
        case .updates: settings.t("tab_updates")
        case .about:   settings.t("tab_about")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：返回 + tab 栏
            HStack(spacing: 8) {
                if let onBack {
                    Button { onBack() } label: {
                        Label(settings.t("back"), systemImage: "chevron.left")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Theme.text)
                    }
                    .buttonStyle(.hit)
                    .padding(.trailing, 6)
                }

                ForEach(Tab.allCases, id: \.self) { t in
                    Button { tab = t } label: {
                        Text(tabTitle(t))
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(tab == t ? Theme.active : Theme.textDim)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(tab == t ? Theme.activeBg : .clear)
                            )
                    }
                    .buttonStyle(.hit)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            // 内容：收敛成一列居中卡片
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .display: DisplayTab()
                    case .general: GeneralTab()
                    case .ports:   PortsTab()
                    case .mcp:     MCPTab()
                    case .stats:   StatsTab()
                    case .updates: UpdatesTab()
                    case .about:   AboutTab()
                    }
                }
                .frame(maxWidth: 720)   // 所有 tab 统一宽度，切换不再跳变
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
            }
        }
        .frame(
            maxWidth: onBack == nil ? 560 : .infinity,
            maxHeight: onBack == nil ? 440 : .infinity
        )
        .background(Theme.bg)
    }
}

// MARK: - 分组卡片 + 行

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border))
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                }
            }
            Spacer(minLength: 16)
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 16) }
}

/// 中性分段控件（替代系统蓝的 .segmented Picker）
struct NeutralSegmented<T: Hashable>: View {
    @Binding var selection: T
    let options: [(String, T)]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.1) { opt in
                Button { selection = opt.1 } label: {
                    Text(opt.0)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selection == opt.1 ? Theme.active : Theme.textDim)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == opt.1 ? Theme.activeBg : .clear)
                        )
                }
                .buttonStyle(.hit)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.bg))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.border))
        .frame(width: 360)
    }
}

// MARK: - 外观

private struct DisplayTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var s = settings
        SettingsCard {
            SettingRow(title: settings.t("appearance")) {
                NeutralSegmented(selection: $s.appearance, options: [
                    (settings.t("appearance_system"), .system),
                    (settings.t("appearance_light"), .light),
                    (settings.t("appearance_dark"), .dark),
                ])
            }
        }
    }
}

// MARK: - 通用（语言 + 开机自启）

private struct GeneralTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var s = settings
        SettingsCard {
            SettingRow(title: settings.t("language"),
                       subtitle: settings.t("lang_note")) {
                NeutralSegmented(selection: $s.language, options: [
                    (settings.t("lang_system"), .system),
                    (settings.t("lang_zh"), .zh),
                    (settings.t("lang_en"), .en),
                ])
            }
            RowDivider()
            SettingRow(title: settings.t("launch_at_login")) {
                Toggle("", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.active)
            }
            RowDivider()
            SettingRow(title: settings.t("notifications")) {
                Toggle("", isOn: $s.notificationsEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.active)
            }
            RowDivider()
            SettingRow(title: settings.t("alert_mem"), subtitle: settings.t("alert_hint")) {
                numField($s.memAlertMB, unit: "MB")
            }
            RowDivider()
            SettingRow(title: settings.t("alert_cpu"), subtitle: settings.t("alert_hint")) {
                numField($s.cpuAlertPct, unit: "%")
            }
        }
    }

    private func numField(_ v: Binding<Double>, unit: String) -> some View {
        HStack(spacing: 5) {
            TextField("0", value: v, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 66)
                .multilineTextAlignment(.trailing)
                .font(.system(.callout, design: .monospaced))
            Text(unit).font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.textDim)
        }
    }
}

// MARK: - 更新

private struct UpdatesTab: View {
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var updater: UpdaterModel
    @State private var releases: [ChangelogRelease] = []
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard {
                SettingRow(title: settings.t("current_version")) {
                    Text("v\(AppInfo.version)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                }
                RowDivider()
                SettingRow(title: settings.t("check_updates")) {
                    Button {
                        updater.checkForUpdates()
                    } label: {
                        Label(settings.t("check_updates"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(GhostButtonStyle(tint: Theme.active))
                    .disabled(!updater.canCheck)
                }
            }

            if !releases.isEmpty {
                Text(settings.t("changelog"))
                    .font(.system(.callout, design: .monospaced)).bold()
                    .foregroundStyle(Theme.text)
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(releases.indices, id: \.self) { i in
                        releaseView(releases[i])
                    }
                }
            }
        }
        .task {
            let fetched = await Changelog.fetch()   // 每次进更新页都重新拉，拿最新日志
            releases = fetched
            expanded = Set(fetched.prefix(1).map(\.version))   // 默认只展开最新那个
        }
    }

    private func releaseView(_ r: ChangelogRelease) -> some View {
        let isOpen = expanded.contains(r.version)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                if isOpen { expanded.remove(r.version) } else { expanded.insert(r.version) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text("v\(r.version)")
                        .font(.system(.callout, design: .monospaced)).bold()
                        .foregroundStyle(Theme.text)
                    Text(r.date)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                    Spacer()
                    if !isOpen {
                        Text("\(r.entries.count)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.textDim)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.hit)

            if isOpen {
                ForEach(r.entries.indices, id: \.self) { j in
                    let e = r.entries[j]
                    HStack(alignment: .top, spacing: 10) {
                        Text(e.kind)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.textDim)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.activeBg, in: Capsule())
                            .frame(width: 68, alignment: .center)
                        Text(e.localized(settings.resolvedLanguage))
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            Divider().padding(.top, 4)
        }
    }
}

// MARK: - MCP 接入

private struct MCPTab: View {
    @Environment(AppSettings.self) private var settings
    private var zh: Bool { settings.resolvedLanguage == .zh }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MCP integration")
                    .font(.system(.title3, design: .monospaced)).bold()
                    .foregroundStyle(Theme.text)
                Text(zh ? "让 AI 工具(Claude Code / Codex / Cursor)控制你的 dev 进程"
                        : "connect AI tools to control your processes")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
            }

            block("Claude Code", MCPInfo.claude)
            block("Codex", MCPInfo.codex)
            block(zh ? "Cursor / 其它" : "Cursor / others", MCPInfo.raw)

            Text(zh ? "先在 mcp/ 目录跑一次 npm install；DevManager 需保持运行(本地接口 127.0.0.1:\(ControlServer.port))。"
                    : "Run npm install in mcp/ once; keep DevManager running (local API on 127.0.0.1:\(ControlServer.port)).")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textDim)
        }
    }

    private func block(_ title: String, _ cmd: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textDim)
            HStack(alignment: .top, spacing: 8) {
                Text(cmd)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.active)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.hit).foregroundStyle(Theme.textDim)
                .help(zh ? "复制" : "copy")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
        }
    }
}

// MARK: - 关于

private struct AboutTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        SettingsCard {
            HStack(alignment: .center, spacing: 18) {
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable().frame(width: 72, height: 72)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("DevManager")
                        .font(.system(.title2, design: .monospaced)).bold()
                        .foregroundStyle(Theme.text)
                    Text("v\(AppInfo.version)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                    Text(settings.t("about_desc"))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                        .padding(.top, 4)
                }
                Spacer()
            }
            .padding(20)
        }
    }
}
