import SwiftUI

/// 极简 sparkline:把一组数值画成折线(自动按窗口内最大值归一化)。
struct Sparkline: View {
    let data: [Double]
    var color: Color = Theme.active

    var body: some View {
        GeometryReader { geo in
            let pts = data
            let maxV = max(pts.max() ?? 1, 0.0001)
            Path { p in
                guard pts.count >= 2 else { return }
                let stepX = geo.size.width / CGFloat(pts.count - 1)
                for (i, v) in pts.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(min(v / maxV, 1)))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
