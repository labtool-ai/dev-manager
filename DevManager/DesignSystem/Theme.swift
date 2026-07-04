import SwiftUI
import AppKit

// MARK: - Color helpers

extension Color {
    /// 16 进制构造：Color(hex: 0x1A1B1D)
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue:  Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }

    /// 跟随系统的 light / dark 动态色
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
    }
}

// MARK: - 中性灰语义色板（一套值，自动切换 dark / light）

enum Metrics {
    /// 窗口底部条高度：侧栏状态栏 & 详情底部留白共用，保证两栏底边对齐
    static let bottomBar: CGFloat = 34
}

enum Theme {
    static let bg      = Color(light: Color(hex: 0xFAFAFA), dark: Color(hex: 0x1A1B1D))
    static let surface = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x232427))
    static let border  = Color(light: Color(hex: 0xE6E6E8), dark: Color(hex: 0x33353A))
    static let text    = Color(light: Color(hex: 0x1D1D1F), dark: Color(hex: 0xE8E8EA))
    static let textDim = Color(light: Color(hex: 0x6E6E73), dark: Color(hex: 0x8A8C92))

    /// 中性激活色：用于选中 / 主操作 / 运行状态等所有"激活"表达（不再用绿色）
    static let active  = Color(light: Color(hex: 0x3A3A3D), dark: Color(hex: 0xD4D4D8))
    /// 激活态的浅底
    static let activeBg = Color(light: Color(hex: 0x000000, alpha: 0.06),
                                dark:  Color(hex: 0xFFFFFF, alpha: 0.10))

    static let stopped = Color(light: Color(hex: 0x9A9AA0), dark: Color(hex: 0x6E7075))

    // 以下仅供日志 ANSI 还原终端自身的彩色输出使用，不用于 UI 装饰
    static let accent  = Color(light: Color(hex: 0x3B82F6), dark: Color(hex: 0x4F8CF7))
    static let running = Color(light: Color(hex: 0x22A45D), dark: Color(hex: 0x2ECC71))
}
