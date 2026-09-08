import AppKit
import SwiftUI

/// NSHostingView 默认可能是不透明的(背景 = 系统窗口灰),会把身后的毛玻璃整块盖住。
/// 强制非不透明 + 清空 layer 背景,才能透出 contentView 的 NSVisualEffectView。
private final class TransparentHostingView: NSHostingView<AnyView> {
    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    @available(*, unavailable) required init(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }
}

/// 自建菜单栏承载:NSStatusItem + 无边框 NSPanel,panel 的 contentView 直接是
/// NSVisualEffectView(里面挂 MenuBarView)。这样才能拿到和系统菜单/ChatGPT 一致的
/// 原生毛玻璃 —— SwiftUI 的 MenuBarExtra(.window) 宿主视图不透明,做不到。
@MainActor
final class StatusItemController: NSObject, NSWindowDelegate {
    private let manager: ProcessManager
    private let settings: AppSettings

    private let statusItem: NSStatusItem
    private var panel: NSPanel?
    private var hostingView: TransparentHostingView?
    private var clickMonitorGlobal: Any?
    private var clickMonitorLocal: Any?

    init(manager: ProcessManager, settings: AppSettings) {
        self.manager = manager
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let img = NSImage(named: "MenuBarIcon")
            img?.isTemplate = true          // 让系统按明暗自动着色
            button.image = img
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(togglePanel)
        }
    }

    // MARK: - 开关

    @objc private func togglePanel() {
        if panel?.isVisible == true { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        let panel = ensurePanel()
        // 内容会变(运行中项目数不同),每次按 SwiftUI 实际尺寸调整
        hostingView?.layoutSubtreeIfNeeded()
        let size = hostingView?.fittingSize ?? NSSize(width: 268, height: 120)
        panel.setContentSize(size)

        positionPanel(panel, size: size)
        panel.makeKeyAndOrderFront(nil)
        startClickMonitors()
    }

    private func hidePanel() {
        stopClickMonitors()
        panel?.orderOut(nil)
    }

    // MARK: - 定位(状态栏图标正下方,水平居中,超出屏幕则贴边)

    private func positionPanel(_ panel: NSPanel, size: NSSize) {
        guard let button = statusItem.button, let btnWin = button.window else { return }
        let btnRectScreen = btnWin.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = btnWin.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        var x = btnRectScreen.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = btnRectScreen.minY - size.height - 6   // 图标下方留 6pt
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Panel(内容视图 = NSVisualEffectView)

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        // 关键:必须用 .titled + .fullSizeContentView(标题栏隐藏),不能用 .borderless——
        // borderless 窗口不吃 .behindWindow 毛玻璃合成,会退化成实心灰。
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 268, height: 200),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.isFloatingPanel = true
        p.level = .statusBar
        p.hidesOnDeactivate = false
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovable = false
        p.isMovableByWindowBackground = false
        p.collectionBehavior = [.moveToActiveSpace, .stationary, .fullScreenAuxiliary]
        p.delegate = self

        // 毛玻璃当 contentView —— 这是拿到原生质感的关键。
        // 圆角必须用 maskImage,不能用 layer.cornerRadius+masksToBounds:
        // 后者会把视图逼成离屏渲染,破坏 .behindWindow 采样 → 退化成实心灰。
        let fx = NSVisualEffectView()
        fx.material = .sidebar           // 和主窗口左侧栏(NavigationSplitView)同款质感
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.maskImage = Self.roundedMask(radius: 10)
        p.contentView = fx

        // SwiftUI 内容挂进毛玻璃视图层级。
        // 注意:不要在这里加 .preferredColorScheme —— 它会给 NSHostingView 套一层
        // 不透明的配色背景,把毛玻璃盖成灰。菜单栏跟随系统外观即可。
        let root = AnyView(
            MenuBarView()
                .environment(manager)
                .environment(settings)
        )
        let host = TransparentHostingView(rootView: root)
        host.translatesAutoresizingMaskIntoConstraints = false
        fx.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: fx.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
            host.topAnchor.constraint(equalTo: fx.topAnchor),
            host.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
        ])

        self.hostingView = host
        self.panel = p
        return p
    }

    /// 可拉伸的圆角遮罩(capInsets),给毛玻璃视图做圆角又不破坏 vibrancy
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let d = radius * 2 + 1
        let image = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    // MARK: - 点外面关闭

    private func startClickMonitors() {
        stopClickMonitors()
        clickMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hidePanel() }
        }
        clickMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            // 点在 panel 之外(含状态栏图标交给 toggle 处理)→ 关闭
            if event.window != panel { Task { @MainActor in self.hidePanel() } }
            return event
        }
    }

    private func stopClickMonitors() {
        if let m = clickMonitorGlobal { NSEvent.removeMonitor(m); clickMonitorGlobal = nil }
        if let m = clickMonitorLocal { NSEvent.removeMonitor(m); clickMonitorLocal = nil }
    }

    func windowDidResignKey(_ notification: Notification) {
        hidePanel()
    }
}
