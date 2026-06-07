import Carbon
import AppKit

extension Notification.Name {
    static let beeFocusToggleTimer = Notification.Name("beeFocusToggleTimer")
    static let beeFocusOpenNewTask = Notification.Name("beeFocusOpenNewTask")
}

final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var refs: [EventHotKeyRef] = []
    private var carbonHandler: EventHandlerRef?

    private init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                let mgr = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { mgr.fire(id: hkID.id) }
                return noErr
            },
            1, &spec, selfPtr, &carbonHandler
        )

        // ⌥⌘T → Timer toggle
        register(id: 1, keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | optionKey))
        // ⌥⌘N → Quick add window
        register(id: 2, keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | optionKey))
    }

    private func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        var hkID = EventHotKeyID()
        hkID.signature = fourCharCode("BeFo")
        hkID.id = id
        var ref: EventHotKeyRef?
        if RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref) == noErr,
           let ref {
            refs.append(ref)
        }
    }

    private func fire(id: UInt32) {
        switch id {
        case 1: NotificationCenter.default.post(name: .beeFocusToggleTimer, object: nil)
        case 2: NotificationCenter.default.post(name: .beeFocusOpenNewTask, object: nil)
        default: break
        }
    }

    private func fourCharCode(_ s: String) -> FourCharCode {
        s.utf8.prefix(4).reduce(0) { ($0 << 8) | FourCharCode($1) }
    }

    deinit {
        refs.forEach { UnregisterEventHotKey($0) }
        if let h = carbonHandler { RemoveEventHandler(h) }
    }
}
