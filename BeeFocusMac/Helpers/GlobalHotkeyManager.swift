import Carbon
import AppKit
import Combine

extension Notification.Name {
    static let beeFocusToggleTimer = Notification.Name("beeFocusToggleTimer")
    static let beeFocusOpenNewTask = Notification.Name("beeFocusOpenNewTask")
    static let beeFocusTogglePanel = Notification.Name("beeFocusTogglePanel")
}

// MARK: - HotkeyConfig

struct HotkeyConfig: Codable, Equatable {
    var keyCode: Int
    var modifiers: UInt32
    var enabled: Bool = true

    static let none = HotkeyConfig(keyCode: -1, modifiers: 0, enabled: false)

    var isNone: Bool { keyCode < 0 || !enabled }

    var displayString: String {
        guard !isNone else { return "–" }
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += Self.keyCodeToString(keyCode)
        return s
    }

    func conflictsWith(_ other: HotkeyConfig) -> Bool {
        guard !isNone && !other.isNone else { return false }
        return keyCode == other.keyCode && modifiers == other.modifiers
    }

    static func keyCodeToString(_ code: Int) -> String {
        switch code {
        case Int(kVK_ANSI_A): return "A"
        case Int(kVK_ANSI_B): return "B"
        case Int(kVK_ANSI_C): return "C"
        case Int(kVK_ANSI_D): return "D"
        case Int(kVK_ANSI_E): return "E"
        case Int(kVK_ANSI_F): return "F"
        case Int(kVK_ANSI_G): return "G"
        case Int(kVK_ANSI_H): return "H"
        case Int(kVK_ANSI_I): return "I"
        case Int(kVK_ANSI_J): return "J"
        case Int(kVK_ANSI_K): return "K"
        case Int(kVK_ANSI_L): return "L"
        case Int(kVK_ANSI_M): return "M"
        case Int(kVK_ANSI_N): return "N"
        case Int(kVK_ANSI_O): return "O"
        case Int(kVK_ANSI_P): return "P"
        case Int(kVK_ANSI_Q): return "Q"
        case Int(kVK_ANSI_R): return "R"
        case Int(kVK_ANSI_S): return "S"
        case Int(kVK_ANSI_T): return "T"
        case Int(kVK_ANSI_U): return "U"
        case Int(kVK_ANSI_V): return "V"
        case Int(kVK_ANSI_W): return "W"
        case Int(kVK_ANSI_X): return "X"
        case Int(kVK_ANSI_Y): return "Y"
        case Int(kVK_ANSI_Z): return "Z"
        case Int(kVK_ANSI_0): return "0"
        case Int(kVK_ANSI_1): return "1"
        case Int(kVK_ANSI_2): return "2"
        case Int(kVK_ANSI_3): return "3"
        case Int(kVK_ANSI_4): return "4"
        case Int(kVK_ANSI_5): return "5"
        case Int(kVK_ANSI_6): return "6"
        case Int(kVK_ANSI_7): return "7"
        case Int(kVK_ANSI_8): return "8"
        case Int(kVK_ANSI_9): return "9"
        case Int(kVK_Space):  return "Space"
        case Int(kVK_Return): return "↩"
        case Int(kVK_Tab):    return "⇥"
        case Int(kVK_Escape): return "⎋"
        case Int(kVK_Delete): return "⌫"
        case Int(kVK_F1):  return "F1"
        case Int(kVK_F2):  return "F2"
        case Int(kVK_F3):  return "F3"
        case Int(kVK_F4):  return "F4"
        case Int(kVK_F5):  return "F5"
        case Int(kVK_F6):  return "F6"
        case Int(kVK_F7):  return "F7"
        case Int(kVK_F8):  return "F8"
        case Int(kVK_F9):  return "F9"
        case Int(kVK_F10): return "F10"
        case Int(kVK_F11): return "F11"
        case Int(kVK_F12): return "F12"
        default:            return "?"
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option)  { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
        return mods
    }
}

// MARK: - GlobalHotkeyManager

final class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()

    // Use Published directly — updated only through updateHotkey()
    @Published private(set) var panelHotkey:   HotkeyConfig
    @Published private(set) var timerHotkey:   HotkeyConfig
    @Published private(set) var newTaskHotkey: HotkeyConfig

    // ID 1 = timer, ID 2 = new task, ID 3 = panel
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var carbonHandler: EventHandlerRef?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Load persisted configs — bypass didSet by using _name = Published(wrappedValue:)
        let panel   = Self.load("mac_hotkey_panel")   ?? HotkeyConfig(keyCode: Int(kVK_ANSI_B), modifiers: UInt32(cmdKey | optionKey))
        let timer   = Self.load("mac_hotkey_timer")   ?? HotkeyConfig(keyCode: Int(kVK_ANSI_T), modifiers: UInt32(cmdKey | optionKey))
        let newTask = Self.load("mac_hotkey_newtask") ?? HotkeyConfig(keyCode: Int(kVK_ANSI_N), modifiers: UInt32(cmdKey | optionKey))

        _panelHotkey   = Published(wrappedValue: panel)
        _timerHotkey   = Published(wrappedValue: timer)
        _newTaskHotkey = Published(wrappedValue: newTask)

        // Install Carbon handler FIRST, then register hotkeys
        installCarbonHandler()
        register(id: 1, config: timer)
        register(id: 2, config: newTask)
        register(id: 3, config: panel)
    }

    // MARK: - Public API (called from HotkeyRecorderRow via Binding)

    func updatePanel(_ config: HotkeyConfig) {
        panelHotkey = config
        save(config, key: "mac_hotkey_panel")
        reregister(id: 3, config: config)
    }

    func updateTimer(_ config: HotkeyConfig) {
        timerHotkey = config
        save(config, key: "mac_hotkey_timer")
        reregister(id: 1, config: config)
    }

    func updateNewTask(_ config: HotkeyConfig) {
        newTaskHotkey = config
        save(config, key: "mac_hotkey_newtask")
        reregister(id: 2, config: config)
    }

    // MARK: - Carbon

    private func installCarbonHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(event,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                let mgr = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { mgr.fire(id: hkID.id) }
                return noErr
            },
            1, &spec, selfPtr, &carbonHandler
        )
    }

    private func register(id: UInt32, config: HotkeyConfig) {
        guard !config.isNone else { return }
        var hkID = EventHotKeyID()
        hkID.signature = fourCharCode("BeFo")
        hkID.id = id
        var ref: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(config.keyCode), config.modifiers, hkID,
                               GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
            refs[id] = ref
        }
    }

    private func reregister(id: UInt32, config: HotkeyConfig) {
        if let old = refs[id] { UnregisterEventHotKey(old); refs.removeValue(forKey: id) }
        register(id: id, config: config)
    }

    private func fire(id: UInt32) {
        switch id {
        case 1: NotificationCenter.default.post(name: .beeFocusToggleTimer, object: nil)
        case 2: NotificationCenter.default.post(name: .beeFocusOpenNewTask, object: nil)
        case 3: NotificationCenter.default.post(name: .beeFocusTogglePanel, object: nil)
        default: break
        }
    }

    // MARK: - Persistence

    private static func load(_ key: String) -> HotkeyConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotkeyConfig.self, from: data)
    }

    private func save(_ config: HotkeyConfig, key: String) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func fourCharCode(_ s: String) -> FourCharCode {
        s.utf8.prefix(4).reduce(0) { ($0 << 8) | FourCharCode($1) }
    }

    deinit {
        refs.values.forEach { UnregisterEventHotKey($0) }
        if let h = carbonHandler { RemoveEventHandler(h) }
    }
}
