import AppKit
import Foundation

enum WidgetDisplayMode: String, CaseIterable, Identifiable {
    case position
    case desktopMarket

    var id: String { rawValue }

    var title: String {
        switch self {
        case .position: return "持仓面板"
        case .desktopMarket: return "桌面行情"
        }
    }

    var subtitle: String {
        switch self {
        case .position: return "查看持仓、浮盈和账户状态"
        case .desktopMarket: return "像苹果桌面小组件一样查看行情"
        }
    }
}

final class WindowPreferences {
    static let shared = WindowPreferences()

    private let defaults = UserDefaults.standard

    var autoFitHeight: Bool {
        get {
            guard defaults.object(forKey: Keys.autoFitHeight) != nil else { return true }
            return defaults.bool(forKey: Keys.autoFitHeight)
        }
        set { defaults.set(newValue, forKey: Keys.autoFitHeight) }
    }

    var alwaysOnTop: Bool {
        get { defaults.bool(forKey: Keys.alwaysOnTop) }
        set { defaults.set(newValue, forKey: Keys.alwaysOnTop) }
    }

    var showOnAllSpaces: Bool {
        get { defaults.bool(forKey: Keys.showOnAllSpaces) }
        set { defaults.set(newValue, forKey: Keys.showOnAllSpaces) }
    }

    var opacityPercent: Double {
        get {
            guard defaults.object(forKey: Keys.opacityPercent) != nil else { return 85 }
            return min(max(defaults.double(forKey: Keys.opacityPercent), 30), 100)
        }
        set { defaults.set(min(max(newValue, 30), 100), forKey: Keys.opacityPercent) }
    }

    var maskAmountsByDefault: Bool {
        get {
            guard defaults.object(forKey: Keys.maskAmountsByDefault) != nil else { return false }
            return defaults.bool(forKey: Keys.maskAmountsByDefault)
        }
        set { defaults.set(newValue, forKey: Keys.maskAmountsByDefault) }
    }

    var autoHideSeconds: Double {
        get {
            guard defaults.object(forKey: Keys.autoHideSeconds) != nil else { return 0 }
            return min(max(defaults.double(forKey: Keys.autoHideSeconds), 0), 60)
        }
        set { defaults.set(min(max(newValue, 0), 60), forKey: Keys.autoHideSeconds) }
    }

    var hideOnLock: Bool {
        get {
            guard defaults.object(forKey: Keys.hideOnLock) != nil else { return true }
            return defaults.bool(forKey: Keys.hideOnLock)
        }
        set { defaults.set(newValue, forKey: Keys.hideOnLock) }
    }

    var maskOnAppSwitch: Bool {
        get {
            guard defaults.object(forKey: Keys.maskOnAppSwitch) != nil else { return false }
            return defaults.bool(forKey: Keys.maskOnAppSwitch)
        }
        set { defaults.set(newValue, forKey: Keys.maskOnAppSwitch) }
    }

    var hideMenuBarOnBossKey: Bool {
        get { defaults.bool(forKey: Keys.hideMenuBarOnBossKey) }
        set { defaults.set(newValue, forKey: Keys.hideMenuBarOnBossKey) }
    }

    var bossKey: GlobalHotkey {
        get {
            guard defaults.object(forKey: Keys.bossKeyCode) != nil,
                  defaults.object(forKey: Keys.bossKeyModifiers) != nil else {
                return .default
            }
            return GlobalHotkey(
                keyCode: UInt32(defaults.integer(forKey: Keys.bossKeyCode)),
                modifiers: UInt32(defaults.integer(forKey: Keys.bossKeyModifiers))
            )
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Keys.bossKeyCode)
            defaults.set(Int(newValue.modifiers), forKey: Keys.bossKeyModifiers)
        }
    }

    var glassBlur: Double {
        get {
            guard defaults.object(forKey: Keys.glassBlur) != nil else { return 24 }
            return min(max(defaults.double(forKey: Keys.glassBlur), 8), 40)
        }
        set { defaults.set(min(max(newValue, 8), 40), forKey: Keys.glassBlur) }
    }

    var displayMode: WidgetDisplayMode {
        get {
            guard let rawValue = defaults.string(forKey: Keys.displayMode),
                  let mode = WidgetDisplayMode(rawValue: rawValue) else {
                return .position
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.displayMode) }
    }

    var storedFrame: NSRect? {
        guard defaults.object(forKey: Keys.x) != nil,
              defaults.object(forKey: Keys.y) != nil,
              defaults.object(forKey: Keys.width) != nil,
              defaults.object(forKey: Keys.height) != nil else {
            return nil
        }
        return NSRect(
            x: defaults.double(forKey: Keys.x),
            y: defaults.double(forKey: Keys.y),
            width: defaults.double(forKey: Keys.width),
            height: defaults.double(forKey: Keys.height)
        )
    }

    func save(frame: NSRect) {
        defaults.set(frame.origin.x, forKey: Keys.x)
        defaults.set(frame.origin.y, forKey: Keys.y)
        defaults.set(frame.size.width, forKey: Keys.width)
        defaults.set(frame.size.height, forKey: Keys.height)
    }

    func validFrame(preferredSize: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let saved = storedFrame ?? NSRect(
            x: visibleFrame.maxX - preferredSize.width - 24,
            y: visibleFrame.maxY - preferredSize.height - 24,
            width: preferredSize.width,
            height: preferredSize.height
        )

        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(saved) }) else {
            return NSRect(
                x: visibleFrame.maxX - saved.width - 24,
                y: visibleFrame.maxY - saved.height - 24,
                width: saved.width,
                height: saved.height
            )
        }
        return saved
    }

    private enum Keys {
        static let x = "windowX"
        static let y = "windowY"
        static let width = "windowWidth"
        static let height = "windowHeight"
        static let autoFitHeight = "autoFitHeight"
        static let alwaysOnTop = "alwaysOnTop"
        static let showOnAllSpaces = "showOnAllSpaces"
        static let opacityPercent = "opacityPercent"
        static let displayMode = "displayMode"
        static let maskAmountsByDefault = "maskAmountsByDefault"
        static let autoHideSeconds = "autoHideSeconds"
        static let hideOnLock = "hideOnLock"
        static let maskOnAppSwitch = "maskOnAppSwitch"
        static let hideMenuBarOnBossKey = "hideMenuBarOnBossKey"
        static let bossKeyCode = "bossKeyCode"
        static let bossKeyModifiers = "bossKeyModifiers"
        static let glassBlur = "glassBlur"
    }
}
