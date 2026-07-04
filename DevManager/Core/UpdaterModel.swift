import Foundation
import Combine
import Sparkle

/// Sparkle 自动更新封装。检查更新 → Sparkle 原生弹窗(下载/验签/安装/重启)。
@MainActor
final class UpdaterModel: ObservableObject {
    private let controller: SPUStandardUpdaterController
    @Published var canCheck: Bool = false

    init() {
        // startingUpdater: true → app 启动即拉起 updater（是否自动检查由 Info.plist SUEnableAutomaticChecks 决定）
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheck)
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}

/// app 版本号（读 Info.plist）
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
