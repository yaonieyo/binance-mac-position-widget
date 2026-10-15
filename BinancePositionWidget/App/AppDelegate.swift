import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = PositionStore()
    let preferences = WindowPreferences.shared
    let privacyController = PrivacyController()
    private let globalHotkeyService = GlobalHotkeyService()
    private(set) var panelController: WidgetPanelController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var privacyObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.start()
        panelController = WidgetPanelController(
            store: store,
            privacyController: privacyController,
            preferences: preferences
        ) { [weak self] in
            self?.showSettings(nil)
        }
        setupStatusItem()
        setupGlobalHotkey()
        setupPrivacyObservers()
        panelController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        privacyObservers.forEach {
            NotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        privacyObservers.removeAll()
        globalHotkeyService.unregister()
        store.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuStates(menu)
    }

    @objc private func togglePanel(_ sender: Any?) {
        if privacyController.isWindowHidden {
            leaveBossMode()
        } else {
            panelController.toggle()
        }
    }

    @objc private func fitHeight(_ sender: Any?) {
        panelController.autoFitHeight = true
        panelController.resizeToPreferredHeight(force: true)
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        panelController.alwaysOnTop.toggle()
    }

    @objc private func toggleAllSpaces(_ sender: NSMenuItem) {
        panelController.showOnAllSpaces.toggle()
    }

    @objc private func reconnect(_ sender: Any?) {
        store.reloadSnapshot()
    }

    @objc private func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let settings = NSHostingController(rootView: SettingsView(
                store: store,
                initialOpacityPercent: preferences.opacityPercent,
                initialDisplayMode: preferences.displayMode,
                initialMaskAmountsByDefault: preferences.maskAmountsByDefault,
                initialAutoHideSeconds: preferences.autoHideSeconds,
                initialHideOnLock: preferences.hideOnLock,
                initialMaskOnAppSwitch: preferences.maskOnAppSwitch,
                initialHideMenuBarOnBossKey: preferences.hideMenuBarOnBossKey,
                initialBossKey: preferences.bossKey,
                initialGlassBlur: preferences.glassBlur,
                initialAlwaysOnTop: preferences.alwaysOnTop,
                onOpacityChanged: { [weak self] value in
                    self?.panelController.opacityPercent = value
                },
                onGlassBlurChanged: { [weak self] value in
                    self?.preferences.glassBlur = value
                    self?.panelController.refreshAppearance()
                },
                onDisplayModeChanged: { [weak self] mode in
                    self?.panelController.displayMode = mode
                },
                onAlwaysOnTopChanged: { [weak self] value in
                    self?.panelController.alwaysOnTop = value
                },
                onMoveToRight: { [weak self] in
                    self?.panelController.moveToRightSide()
                },
                onBossKeyChanged: { [weak self] hotkey in
                    guard let self else { return }
                    self.preferences.bossKey = hotkey
                    self.setupGlobalHotkey()
                },
                onToggleBossMode: { [weak self] in
                    self?.toggleBossMode()
                }
            ))
            let window = NSWindow(contentViewController: settings)
            window.title = "持仓组件设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 520, height: 510))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "持仓")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "显示/隐藏窗口", action: #selector(togglePanel(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "设置…", action: #selector(showSettings(_:)), keyEquivalent: ",")

        let alwaysOnTop = NSMenuItem(title: "始终置顶", action: #selector(toggleAlwaysOnTop(_:)), keyEquivalent: "")
        menu.addItem(alwaysOnTop)
        let allSpaces = NSMenuItem(title: "所有桌面显示", action: #selector(toggleAllSpaces(_:)), keyEquivalent: "")
        menu.addItem(allSpaces)

        menu.addItem(.separator())
        menu.addItem(withTitle: "重新读取", action: #selector(reconnect(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "隐藏金额", action: #selector(maskNow(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func maskNow(_ sender: Any?) {
        privacyController.mask()
    }

    private func updateMenuStates(_ menu: NSMenu) {
        menu.items.first(where: { $0.action == #selector(toggleAlwaysOnTop(_:)) })?.state = panelController.alwaysOnTop ? .on : .off
        menu.items.first(where: { $0.action == #selector(toggleAllSpaces(_:)) })?.state = panelController.showOnAllSpaces ? .on : .off
    }

    private func setupGlobalHotkey() {
        globalHotkeyService.register(hotkey: preferences.bossKey) { [weak self] in
            self?.toggleBossMode()
        }
    }

    private func toggleBossMode() {
        if privacyController.toggleBossMode() {
            panelController.hide()
            settingsWindow?.orderOut(nil)
            if preferences.hideMenuBarOnBossKey {
                statusItem.isVisible = false
            }
        } else {
            statusItem.isVisible = true
            panelController.show()
        }
    }

    private func leaveBossMode() {
        privacyController.leaveBossMode()
        statusItem.isVisible = true
        panelController.show()
    }

    private func setupPrivacyObservers() {
        let appObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.privacyController.applicationBecameInactive()
            }
        }
        privacyObservers.append(appObserver)

        let workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.preferences.hideOnLock else { return }
                self.privacyController.mask()
            }
        }
        privacyObservers.append(workspaceObserver)
    }
}
