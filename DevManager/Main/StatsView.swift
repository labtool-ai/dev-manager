import SwiftUI

/// 设置里的「统计」页：汇总卡片 + 启动活动热力图 + 洞察 + 最常用项目
struct StatsTab: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ProcessManager.self) private var pm

    @State private var mode: HeatmapMode = .daily

    private var stats: UsageStats { pm.stats }

    /// 当前正在运行(尚未记录)的会话实时累计秒数——让长会话即时可见，不必等停止/退出
    private var liveRunningSec: Double {
        let now = Date()
        return pm.processes.reduce(0.0) { acc, p in
            guard p.state == .running, let s = p.startDate else { return acc }
            return acc + now.timeIntervalSince(s)
        }
    }
    private var liveLongestSec: Double {
        let now = Date()
        return pm.processes.compactMap { p -> Double? in
            guard p.state == .running, let s = p.startDate else { return nil }
            return now.timeIntervalSince(s)
        }.max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            summaryCards
            heatmapSection
            HStack(alignment: .top, spacing: 24) {
                insights
                topProjects
            }
            footer
        }
    }

    // MARK: - 汇总卡片

    private var summaryCards: some View {
        SettingsCard {
            HStack(spacing: 0) {
                statCell(fmtCount(stats.totalRuns), settings.t("stat_total_runs"))
                cellDivider
                statCell(fmtDuration(stats.totalRuntimeSec + liveRunningSec), settings.t("stat_total_runtime"))
                cellDivider
                statCell(fmtDuration(max(stats.longestRunSec, liveLongestSec)), settings.t("stat_longest_run"))
                cellDivider
                statCell("\(stats.currentStreak) \(settings.t("unit_days"))", settings.t("stat_current_streak"))
                cellDivider
                statCell("\(stats.longestStreak) \(settings.t("unit_days"))", settings.t("stat_longest_streak"))
            }
            .padding(.vertical, 16)
        }
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var cellDivider: some View {
        Rectangle().fill(Theme.border).frame(width: 1, height: 34)
    }

    // MARK: - 热力图（带 每日/每周/累计 切换）

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(settings.t("launch_activity"))
                    .font(.system(.callout, design: .monospaced)).bold()
                    .foregroundStyle(Theme.text)
                Spacer()
                HStack(spacing: 12) {
                    ForEach(HeatmapMode.allCases, id: \.self) { m in
                        Button { mode = m } label: {
                            Text(modeTitle(m))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(mode == m ? Theme.text : Theme.textDim)
                        }
                        .buttonStyle(.hit)
                    }
                }
            }
            HeatmapView(
                colorCounts: stats.countsByDay(mode),
                dayCounts: stats.dailyCounts(),
                language: settings.resolvedLanguage,
                runsUnit: settings.t("unit_runs_short")
            )
        }
    }

    private func modeTitle(_ m: HeatmapMode) -> String {
        switch m {
        case .daily:      settings.t("mode_daily")
        case .weekly:     settings.t("mode_weekly")
        case .cumulative: settings.t("mode_cumulative")
        }
    }

    // MARK: - 洞察

    private var insights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("insights"))
                .font(.system(.callout, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)
            insightRow(settings.t("insight_projects"), "\(pm.processes.count)")
            insightRow(settings.t("insight_tags"), "\(stats.distinctTags)")
            insightRow(settings.t("insight_active_hour"), activeHourText)
            insightRow(settings.t("insight_crashes"), "\(stats.crashCount)",
                       valueColor: stats.crashCount > 0 ? Theme.stopped : Theme.text)
            insightRow(settings.t("insight_avg_runtime"), fmtDuration(stats.avgRuntimeSec))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeHourText: String {
        guard let h = stats.mostActiveHour else { return "—" }
        return String(format: "%02d:00", h)
    }

    private func insightRow(_ key: String, _ value: String, valueColor: Color = Theme.text) -> some View {
        HStack {
            Text(key).foregroundStyle(Theme.textDim)
            Spacer()
            Text(value).foregroundStyle(valueColor)
        }
        .font(.system(.callout, design: .monospaced))
    }

    // MARK: - 最常用项目

    private var topProjects: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("top_projects"))
                .font(.system(.callout, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)
            let top = stats.topProjects()
            if top.isEmpty {
                Text("—").foregroundStyle(Theme.textDim)
                    .font(.system(.callout, design: .monospaced))
            } else {
                ForEach(top, id: \.name) { item in
                    HStack {
                        Text(item.name)
                            .foregroundStyle(Theme.text).lineLimit(1)
                        Spacer()
                        Text("\(item.count) \(settings.t("runs_unit"))")
                            .foregroundStyle(Theme.textDim)
                    }
                    .font(.system(.callout, design: .monospaced))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 页脚（空态提示 / 清空示例数据）

    @ViewBuilder private var footer: some View {
        if stats.totalRuns == 0 {
            Text(settings.t("no_stats"))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textDim)
        } else {
            HStack {
                Spacer()
                Button {
                    stats.clear()
                } label: {
                    Label("\(settings.t("sample_data")) · \(settings.t("clear"))", systemImage: "trash")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                }
                .buttonStyle(.hit)
                .help(settings.t("no_stats"))
            }
        }
    }

    // MARK: - 格式化

    private func fmtCount(_ n: Int) -> String { "\(n)" }

    private func fmtDuration(_ sec: Double) -> String {
        let s = Int(sec)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        let h = s / 3600, m = (s % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

// MARK: - 热力图（GitHub 贡献图样式，53 周 × 7 天，hover 显示当天次数）

struct HeatmapView: View {
    let colorCounts: [Date: Int]
    let dayCounts: [Date: Int]
    var language: Localization.Lang = .en
    var runsUnit: String = "runs"

    private let weeks = 53
    private let gap: CGFloat = 3
    private let cal = Calendar.current

    var body: some View {
        let grid = buildGrid()
        let maxCount = max(1, colorCounts.values.max() ?? 1)

        // 按容器宽度自适应算格子大小：整年正好铺满整行，右侧不留白、也不溢出
        GeometryReader { geo in
            let cell = max(6, min(13, (geo.size.width - CGFloat(weeks - 1) * gap) / CGFloat(weeks)))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: gap) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                cellView(day: day, maxCount: maxCount, cell: cell)
                            }
                        }
                    }
                }
                monthLabels(grid: grid, cell: cell)
            }
        }
        .frame(height: 7 * 13 + 6 * gap + 6 + 12)   // 兜住最大格子(13)时的高度
    }

    @ViewBuilder
    private func cellView(day: Date?, maxCount: Int, cell: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(color(for: day, maxCount: maxCount))
            .frame(width: cell, height: cell)
            .help(tooltip(for: day))
    }

    private func tooltip(for day: Date?) -> String {
        guard let day else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: language == .zh ? "zh_CN" : "en_US")
        fmt.dateFormat = language == .zh ? "yyyy年M月d日" : "MMM d, yyyy"
        let n = dayCounts[day] ?? 0
        return "\(fmt.string(from: day)) · \(n) \(runsUnit)"
    }

    private func color(for day: Date?, maxCount: Int) -> Color {
        guard let day, let c = colorCounts[day], c > 0 else { return Theme.textDim.opacity(0.12) }
        let ratio = Double(c) / Double(maxCount)
        let bucket = ratio > 0.66 ? 1.0 : ratio > 0.33 ? 0.7 : 0.4
        // 强度用颜色浓淡表达（热力图是唯一保留的强度色）
        return Theme.accent.opacity(0.35 + bucket * 0.55)
    }

    /// 构建 53 列，每列 7 天（周日→周六），最后一列含今天
    private func buildGrid() -> [[Date?]] {
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
        guard let thisSunday = cal.date(byAdding: .day, value: -(weekday - 1), to: today) else { return [] }
        guard let start = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: thisSunday) else { return [] }

        var grid: [[Date?]] = []
        for w in 0..<weeks {
            var week: [Date?] = []
            for d in 0..<7 {
                if let day = cal.date(byAdding: .day, value: w * 7 + d, to: start) {
                    week.append(day > today ? nil : day)
                } else {
                    week.append(nil)
                }
            }
            grid.append(week)
        }
        return grid
    }

    /// 底部月份标签
    private func monthLabels(grid: [[Date?]], cell: CGFloat) -> some View {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: language == .zh ? "zh_CN" : "en_US")
        fmt.dateFormat = language == .zh ? "M月" : "MMM"

        var labels: [(offset: Int, text: String)] = []
        var lastMonth = -1
        for (i, week) in grid.enumerated() {
            if let first = week.compactMap({ $0 }).first {
                let m = cal.component(.month, from: first)
                if m != lastMonth {
                    labels.append((i, fmt.string(from: first)))
                    lastMonth = m
                }
            }
        }

        return ZStack(alignment: .topLeading) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label.text)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
                    .offset(x: CGFloat(label.offset) * (cell + gap))
            }
        }
        .frame(height: 12, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
