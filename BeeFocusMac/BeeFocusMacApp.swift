import Combine
import SwiftUI
import UserNotifications

// MARK: - App

@main
struct BeeFocusMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    let todoStore = MacTodoStore()
    let timerMgr  = MacTimerManager()

    private var statusItem:      NSStatusItem!
    private var panel:           NSPanel!
    private var labelHostingView: NSHostingView<AnyView>!
    private var eventMonitor:    Any?
    private var cancellables     = Set<AnyCancellable>()

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
        MacCloudSettingsSync.shared.start()
        _ = GlobalHotkeyManager.shared
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPanel()
    }

    // MARK: Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let labelView = AnyView(MenuBarLabel().environmentObject(timerMgr))
        labelHostingView = NSHostingView(rootView: labelView)
        updateStatusItemFrame()

        if let btn = statusItem.button {
            btn.addSubview(labelHostingView)
            btn.action = #selector(togglePanel)
            btn.target  = self
            btn.sendAction(on: .leftMouseDown)
        }

        timerMgr.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateStatusItemFrame() }
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemFrame() {
        let height = NSStatusBar.system.thickness
        let width  = max(28, labelHostingView.fittingSize.width)
        let frame  = NSRect(x: 0, y: 0, width: width, height: height)
        labelHostingView.frame   = frame
        statusItem.button?.frame = frame
    }

    @objc private func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        NSUbiquitousKeyValueStore.default.synchronize()
        MacCloudSettingsSync.shared.forceSync()
        guard let btn = statusItem.button, let btnWin = btn.window else { return }
        let btnFrame = btnWin.convertToScreen(btn.frame)
        var x = btnFrame.midX - panel.frame.width / 2
        let y = btnFrame.minY - panel.frame.height - 4
        if let screen = NSScreen.main {
            let vis = screen.visibleFrame
            x = max(vis.minX, min(vis.maxX - panel.frame.width, x))
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)

        // Close when user clicks outside the panel
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func hidePanel() {
        panel.orderOut(nil)
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    // MARK: Panel

    private func setupPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 500),
            styleMask:   [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing:     .buffered,
            defer:       true
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility            = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden      = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden        = true
        panel.level                  = .statusBar
        panel.collectionBehavior     = [.canJoinAllSpaces, .transient]
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel         = true
        panel.minSize                 = NSSize(width: 320, height: 440)
        panel.delegate                = self

        let content = AnyView(
            MenuBarContentView()
                .environmentObject(todoStore)
                .environmentObject(timerMgr)
        )
        let hv = NSHostingView(rootView: content)
        hv.translatesAutoresizingMaskIntoConstraints = true
        panel.contentView = hv
    }

    // MARK: NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hidePanel()
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    @EnvironmentObject var timerMgr: MacTimerManager
    @AppStorage("aktivesStatistikThema") private var activeTheme: String = ""

    private var accent: Color {
        timerMgr.isRunning ? timerMgr.mode.color : (activeTheme.isEmpty ? .orange : activeTheme.themeAccent)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(timerMgr.isRunning ? accent : accent.opacity(0.8))
            if timerMgr.isRunning {
                Text(timerMgr.timeString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 4)
    }
}
