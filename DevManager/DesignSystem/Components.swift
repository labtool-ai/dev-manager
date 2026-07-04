import SwiftUI

// MARK: - 状态点

struct StatusDot: View {
    let state: RunState

    // 用"强度"表达状态：运行=实心深、启动中=中、停止=淡
    private var color: Color {
        switch state {
        case .running:  Theme.active
        case .starting: Theme.textDim
        case .stopped:  Theme.textDim.opacity(0.35)
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

// MARK: - 标签胶囊

struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(Theme.textDim)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.activeBg)
            .clipShape(Capsule())
    }
}

// MARK: - 幽灵按钮

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Theme.active
    /// 实心反相：tint 作背景，前景反白(自动适配亮/暗)
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(.callout, design: .monospaced))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(filled ? Theme.surface : tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(filled ? tint.opacity(pressed ? 0.82 : 1.0)
                                 : tint.opacity(pressed ? 0.20 : 0.10))
            )
            .overlay {
                if !filled {
                    RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.4))
                }
            }
    }
}

// MARK: - Tag 彩色图标（按 tag 名确定性生成，同名恒定）

enum TagStyle {
    static let symbols = [
        "cube.box.fill", "hammer.fill", "bolt.fill", "flame.fill", "leaf.fill",
        "globe", "cpu.fill", "server.rack", "chart.bar.fill", "paintbrush.fill",
        "wrench.and.screwdriver.fill", "shippingbox.fill", "square.stack.3d.up.fill",
        "network", "testtube.2", "book.fill", "star.fill", "gearshape.fill",
        "terminal.fill", "sparkles"
    ]
    static let colors: [Color] = [
        Color(hex: 0x3B82F6), Color(hex: 0xF59E0B), Color(hex: 0x22A45D),
        Color(hex: 0xE0524F), Color(hex: 0x8B5CF6), Color(hex: 0x0EA5A5),
        Color(hex: 0xEC4899), Color(hex: 0x6366F1), Color(hex: 0xCA8A04),
        Color(hex: 0x14B8A6)
    ]

    static func hash(_ s: String) -> Int {
        var h = 5381
        for u in s.unicodeScalars { h = ((h << 5) &+ h) &+ Int(u.value) }
        return abs(h)
    }
    static func symbol(for tag: String) -> String { symbols[hash(tag) % symbols.count] }
    static func color(for tag: String) -> Color { colors[(hash(tag) / symbols.count) % colors.count] }
}

struct TagIcon: View {
    let tag: String
    var size: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(TagStyle.color(for: tag).gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: TagStyle.symbol(for: tag))
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - 流式换行布局（放不下自动换到下一行）

struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxRow: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 {
                maxRow = max(maxRow, x - spacing)
                x = 0; y += rowHeight + lineSpacing; rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        maxRow = max(maxRow, x - spacing)
        return CGSize(width: min(maxWidth, maxRow), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + lineSpacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

// MARK: - 空态占位

struct ContentPlaceholder: View {
    @Environment(AppSettings.self) private var settings
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .font(.system(size: 34))
                .foregroundStyle(Theme.textDim)
            Text(settings.t("select_project"))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
