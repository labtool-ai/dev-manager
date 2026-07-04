import SwiftUI

/// 极简 ANSI SGR 解析：把带颜色转义码的日志行转成带色 AttributedString。
/// 覆盖 npm / vite 常见的前景色、bright 色、bold、reset；其它转义序列直接吞掉。
enum ANSI {
    /// 去掉所有转义码，用于搜索匹配
    static func strip(_ s: String) -> String {
        var result = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == "\u{1B}", i + 1 < chars.count, chars[i + 1] == "[" {
                i += 2
                while i < chars.count, !("@"..."~").contains(chars[i]) { i += 1 }
                i += 1 // 跳过终止字母
            } else {
                result.append(chars[i]); i += 1
            }
        }
        return result
    }

    static func attributed(_ s: String) -> AttributedString {
        var out = AttributedString("")
        var fg: Color? = nil
        var bold = false
        var buffer = ""

        func flush() {
            guard !buffer.isEmpty else { return }
            var piece = AttributedString(buffer)
            if let fg { piece.foregroundColor = fg } else { piece.foregroundColor = Theme.textDim }
            if bold { piece.font = .system(.caption, design: .monospaced).bold() }
            out.append(piece)
            buffer = ""
        }

        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == "\u{1B}", i + 1 < chars.count, chars[i + 1] == "[" {
                flush()
                i += 2
                var params = ""
                while i < chars.count, !("@"..."~").contains(chars[i]) {
                    params.append(chars[i]); i += 1
                }
                let terminator: Character? = i < chars.count ? chars[i] : nil
                i += 1
                if terminator == "m" { applySGR(params, fg: &fg, bold: &bold) }
            } else {
                buffer.append(chars[i]); i += 1
            }
        }
        flush()
        return out
    }

    private static func applySGR(_ params: String, fg: inout Color?, bold: inout Bool) {
        let codes = params.split(separator: ";").map { Int($0) ?? 0 }
        var idx = 0
        while idx < codes.count {
            let code = codes[idx]
            switch code {
            case 0: fg = nil; bold = false
            case 1: bold = true
            case 22: bold = false
            case 39: fg = nil
            case 30...37: fg = basic(code - 30)
            case 90...97: fg = bright(code - 90)
            case 38:
                // 38;5;n 或 38;2;r;g;b —— 跳过参数，用近似色
                if idx + 1 < codes.count, codes[idx + 1] == 5 { idx += 2; fg = Theme.accent }
                else if idx + 1 < codes.count, codes[idx + 1] == 2 { idx += 4; fg = Theme.accent }
            default: break
            }
            idx += 1
        }
    }

    private static func basic(_ n: Int) -> Color {
        switch n {
        case 0: Color(hex: 0x6E6E73)          // black → 灰
        case 1: Color(hex: 0xE05252)          // red
        case 2: Theme.running                  // green
        case 3: Color(hex: 0xC9A227)          // yellow
        case 4: Theme.accent                   // blue
        case 5: Color(hex: 0xB05CC9)          // magenta
        case 6: Color(hex: 0x2EA9B0)          // cyan
        default: Theme.text                    // white
        }
    }

    private static func bright(_ n: Int) -> Color {
        switch n {
        case 1: Color(hex: 0xF06A6A)
        case 2: Color(hex: 0x3ED47E)
        case 3: Color(hex: 0xE0C044)
        case 4: Color(hex: 0x5B9DF7)
        case 5: Color(hex: 0xC97BDE)
        case 6: Color(hex: 0x45C4CB)
        default: Theme.text
        }
    }
}
