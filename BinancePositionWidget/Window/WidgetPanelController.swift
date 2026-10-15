import AppKit
import SwiftUI

@MainActor
final class WidgetPanelController: NSObject, NSWindowDelegate {
    let store: PositionStore
    let privacyController: PrivacyController
    let preferences: WindowPreferences
    let onShowSettings: () -> Void
    private(set) var panel: NSPanel!
    private var userIsResizing = false
    private var isApplyingAutomaticResize = false

    var autoFitHeight: Bool {
        get { preferences.autoFitHeight }
        set { preferences.autoFitHeight = newValue }
    }

    var alwaysOnTop: Bool {
        get { preferences.alwaysOnTop }
        set {
            preferences.alwaysOnTop = newValue
            panel.level = newValue ? .floating : Self.normalLevel
        }
    }

    var showOnAllSpaces: Bool {
        get { preferences.showOnAllSpaces }
        set {
            preferences.showOnAllSpaces = newValue
            panel.collectionBehavior = newValue ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.fullScreenAuxiliary]
        }
    }

    var opacityPercent: Double {
        get { preferences.opacityPercent }
        set {
            preferences.opacityPercent = newValue
            panel.alphaValue = 1
            installRootView()
        }
    }

    func refreshAppearance() {
        installRootView()
    }

    var displayMode: WidgetDisplayMode {
        get { preferences.displayMode }
        set {
            preferences.displayMode = newValue
            panel.minSize = newValue == .desktopMarket
                ? NSSize(width: 320, height: 230)
                : NSSize(width: 200, height: 200)
            panel.maxSize = newValue == .desktopMarket
                ? NSSize(width: 420, height: 600)
                : NSSize(width: 520, height: 520)
            panel.contentAspectRatio = newValue == .position
                ? NSSize(width: 1, height: 1)
                : .zero
            installRootView()
            resizeToPreferredHeight(animated: false)
        }
    }

    init(
        store: PositionStore,
        privacyController: PrivacyController,
        preferences: WindowPreferences = .shared,
        onShowSettings: @escaping () -> Void = {}
    ) {
        self.store = store
        self.privacyController = privacyController
        self.preferences = preferences
        self.onShowSettings = onShowSettings
        super.init()
        buildPanel()
    }

    func show() {
        if autoFitHeight {
            resizeToPreferredHeight(animated: false)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    func hide() {
        privacyController.mask()
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func moveToRightSide() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var frame = panel.frame
        frame.origin.x = visibleFrame.maxX - frame.width - 24
        frame.origin.y = visibleFrame.maxY - frame.height - 24
        panel.setFrame(frame, display: true)
        preferences.save(frame: frame)
    }

    func resizeToPreferredHeight(animated: Bool = true) {
        resizeToPreferredHeight(animated: animated, force: false)
    }

    /// Grows the panel when new positions arrive even after a user manually
    /// resized it. This prevents rows from being silently hidden below the
    /// fold while still allowing a deliberate manual resize afterward.
    func resizeToPreferredHeight(animated: Bool = true, force: Bool) {
        guard autoFitHeight || force else { return }
        let targetSize: NSSize
        if displayMode == .desktopMarket {
            targetSize = NSSize(width: 320, height: 230)
        } else {
            let side = Self.preferredHeight(
                positionCount: store.positions.count,
                isConfigured: store.isUsingRealData || store.connectionState == .mock
            )
            targetSize = NSSize(width: side, height: side)
        }
        panel.minSize = displayMode == .desktopMarket
            ? NSSize(width: 320, height: 230)
            : NSSize(width: 200, height: 200)
        var frame = panel.frame
        let bottom = frame.minY
        frame.size = targetSize
        frame.origin.y = bottom
        isApplyingAutomaticResize = true

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.21
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel.animator().setFrame(frame, display: true)
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.isApplyingAutomaticResize = false
            }
        } else {
            panel.setFrame(frame, display: true)
            isApplyingAutomaticResize = false
        }
        preferences.save(frame: frame)
    }

    static func preferredHeight(positionCount: Int) -> CGFloat {
        preferredHeight(positionCount: positionCount, isConfigured: true)
    }

    static func preferredHeight(positionCount: Int, isConfigured: Bool) -> CGFloat {
        guard isConfigured else { return 300 }
        switch positionCount {
        case 0, 1: return 220
        default: return 260
        }
    }

    func windowDidMove(_ notification: Notification) {
        preferences.save(frame: panel.frame)
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        guard !isApplyingAutomaticResize else { return }
        userIsResizing = true
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard !isApplyingAutomaticResize else { return }
        if userIsResizing {
            autoFitHeight = false
        }
        userIsResizing = false
        preferences.save(frame: panel.frame)
    }

    func windowDidResize(_ notification: Notification) {
        if !panel.inLiveResize {
            preferences.save(frame: panel.frame)
        }
    }

    private func buildPanel() {
        let initialSize = displayMode == .desktopMarket
            ? NSSize(width: 320, height: 230)
            : NSSize(width: Self.preferredHeight(
                positionCount: store.positions.count,
                isConfigured: store.isUsingRealData || store.connectionState == .mock
            ), height: Self.preferredHeight(
                positionCount: store.positions.count,
                isConfigured: store.isUsingRealData || store.connectionState == .mock
            ))
        var frame = preferences.validFrame(preferredSize: initialSize)
        if displayMode == .position, abs(frame.width - frame.height) > 2 {
            let side = min(max(max(frame.width, frame.height), 300), 380)
            frame.size = NSSize(width: side, height: side)
        }
        panel = DesktopPanel(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.alphaValue = 1
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.minSize = displayMode == .desktopMarket
            ? NSSize(width: 320, height: 230)
            : NSSize(width: 200, height: 200)
        panel.contentAspectRatio = displayMode == .position
            ? NSSize(width: 1, height: 1)
            : .zero
        panel.maxSize = displayMode == .desktopMarket
            ? NSSize(width: 420, height: 600)
            : NSSize(width: 520, height: 520)
        panel.level = alwaysOnTop ? .floating : Self.normalLevel
        panel.collectionBehavior = showOnAllSpaces ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.fullScreenAuxiliary]

        installRootView()
    }

    private func installRootView() {
        let rootView = WidgetRootView(
            store: store,
            privacyController: privacyController,
            onPositionCountChanged: { [weak self] _ in
                guard let self else { return }
                self.resizeToPreferredHeight(force: true)
            },
            onFitHeight: { [weak self] in
                guard let self else { return }
                self.autoFitHeight = true
                self.resizeToPreferredHeight(force: true)
            },
            onToggleAlwaysOnTop: { [weak self] in
                guard let self else { return }
                self.alwaysOnTop.toggle()
            },
            onDisplayModeChanged: { [weak self] mode in
                self?.displayMode = mode
            },
            onToggleMask: { [weak self] in
                self?.privacyController.toggleMask()
            },
            onHideWindow: { [weak self] in
                self?.hide()
            },
            onSetDemoScenario: { [weak self] scenario in
                guard let self else { return }
                if let scenario {
                    self.store.setScenario(scenario)
                    self.resizeToPreferredHeight(force: true)
                } else {
                    self.store.resumeRealData()
                }
            },
            isAlwaysOnTop: alwaysOnTop,
            displayMode: displayMode,
            glassOpacityPercent: preferences.opacityPercent,
            glassBlur: preferences.glassBlur,
            onReloadSnapshot: { [weak self] in
                self?.store.reloadSnapshot()
            },
            onShowSettings: { [weak self] in
                self?.onShowSettings()
            }
        )
        panel.contentViewController = NSHostingController(rootView: rootView)
    }

    /// Non-topmost mode stays at the normal window level so the panel remains interactive.
    private static var normalLevel: NSWindow.Level {
        .normal
    }
}
