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
        labelHostingView.frame = NSRect(x: 0, y: 0, width: 72, height: NSStatusBar.system.thickness)

        if let btn = statusItem.button {
            btn.frame = labelHostingView.frame
            btn.addSubview(labelHostingView)
            btn.action = #selector(togglePanel)
            btn.target  = self
            btn.sendAction(on: .leftMouseDown)
        }
    }

    @objc private func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
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
            ZStack {
                Circle().stroke(Color.primary.opacity(0.15), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: timerMgr.isRunning ? timerMgr.progress : 0)
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerMgr.progress)
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(timerMgr.isRunning ? accent : accent.opacity(0.8))
            }
            .frame(width: 16, height: 16)
            if timerMgr.isRunning {
                Text(timerMgr.timeString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 4)
    }
}
