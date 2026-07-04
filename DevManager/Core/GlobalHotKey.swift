import AppKit
import Carbon.HIToolbox

/// 注册一个系统级全局热键(默认 ⌘⌥K),从任何 app 唤起。
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    var onFire: (() -> Void)?

    /// keyCode: 见 kVK_ANSI_*；modifiers: cmdKey / optionKey / controlKey / shiftKey 的按位或
    init(keyCode: UInt32 = UInt32(kVK_ANSI_K),
         modifiers: UInt32 = UInt32(cmdKey | optionKey)) {

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let this = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            this.onFire?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x444D4B31), id: 1) // 'DMK1'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
