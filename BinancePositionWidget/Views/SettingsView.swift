import AppKit
import SwiftUI

struct SettingsView: View {
    private enum SettingsTab: Hashable {
        case display
        case privacy
        case account
    }

    @ObservedObject var store: PositionStore
    let initialOpacityPercent: Double
    let initialDisplayMode: WidgetDisplayMode
    let initialMaskAmountsByDefault: Bool
    let initialAutoHideSeconds: Double
    let initialHideOnLock: Bool
    let initialMaskOnAppSwitch: Bool
    let initialHideMenuBarOnBossKey: Bool
    let initialBossKey: GlobalHotkey
    let initialGlassBlur: Double
    let initialAlwaysOnTop: Bool
    let onOpacityChanged: (Double) -> Void
    let onGlassBlurChanged: (Double) -> Void
    let onDisplayModeChanged: (WidgetDisplayMode) -> Void
    let onAlwaysOnTopChanged: (Bool) -> Void
    let onMoveToRight: () -> Void
    let onBossKeyChanged: (GlobalHotkey) -> Void
    let onToggleBossMode: () -> Void

    @State private var selectedTab: SettingsTab = .display
    @State private var apiKeyInput = ""
    @State private var apiSecretInput = ""
    @State private var storedAPIKey: String?
    @State private var isEditingCredentials = false
    @State private var isWorking = false
    @State private var notice: String?
    @State private var opacityPercent: Double
    @State private var glassBlur: Double
    @State private var displayMode: WidgetDisplayMode
    @State private var maskAmountsByDefault: Bool
    @State private var autoHideSeconds: Double
    @State private var hideOnLock: Bool
    @State private var maskOnAppSwitch: Bool
    @State private var hideMenuBarOnBossKey: Bool
    @State private var bossKey: GlobalHotkey
    @State private var isRecordingBossKey = false
    @State private var alwaysOnTop: Bool

    init(
        store: PositionStore,
        initialOpacityPercent: Double = WindowPreferences.shared.opacityPercent,
        initialDisplayMode: WidgetDisplayMode = WindowPreferences.shared.displayMode,
        initialMaskAmountsByDefault: Bool = WindowPreferences.shared.maskAmountsByDefault,
        initialAutoHideSeconds: Double = WindowPreferences.shared.autoHideSeconds,
        initialHideOnLock: Bool = WindowPreferences.shared.hideOnLock,
        initialMaskOnAppSwitch: Bool = WindowPreferences.shared.maskOnAppSwitch,
        initialHideMenuBarOnBossKey: Bool = WindowPreferences.shared.hideMenuBarOnBossKey,
        initialBossKey: GlobalHotkey = WindowPreferences.shared.bossKey,
        initialGlassBlur: Double = WindowPreferences.shared.glassBlur,
        initialAlwaysOnTop: Bool = WindowPreferences.shared.alwaysOnTop,
        onOpacityChanged: @escaping (Double) -> Void = { WindowPreferences.shared.opacityPercent = $0 },
        onGlassBlurChanged: @escaping (Double) -> Void = { WindowPreferences.shared.glassBlur = $0 },
        onDisplayModeChanged: @escaping (WidgetDisplayMode) -> Void = { WindowPreferences.shared.displayMode = $0 },
        onAlwaysOnTopChanged: @escaping (Bool) -> Void = { WindowPreferences.shared.alwaysOnTop = $0 },
        onMoveToRight: @escaping () -> Void = {},
        onBossKeyChanged: @escaping (GlobalHotkey) -> Void = { WindowPreferences.shared.bossKey = $0 },
        onToggleBossMode: @escaping () -> Void = {}
    ) {
        self.store = store
        self.initialOpacityPercent = initialOpacityPercent
        self.initialDisplayMode = initialDisplayMode
        self.initialMaskAmountsByDefault = initialMaskAmountsByDefault
        self.initialAutoHideSeconds = initialAutoHideSeconds
        self.initialHideOnLock = initialHideOnLock
        self.initialMaskOnAppSwitch = initialMaskOnAppSwitch
        self.initialHideMenuBarOnBossKey = initialHideMenuBarOnBossKey
        self.initialBossKey = initialBossKey
        self.initialGlassBlur = initialGlassBlur
        self.initialAlwaysOnTop = initialAlwaysOnTop
        self.onOpacityChanged = onOpacityChanged
        self.onGlassBlurChanged = onGlassBlurChanged
        self.onDisplayModeChanged = onDisplayModeChanged
        self.onAlwaysOnTopChanged = onAlwaysOnTopChanged
        self.onMoveToRight = onMoveToRight
        self.onBossKeyChanged = onBossKeyChanged
        self.onToggleBossMode = onToggleBossMode
        _opacityPercent = State(initialValue: initialOpacityPercent)
        _glassBlur = State(initialValue: initialGlassBlur)
        _displayMode = State(initialValue: initialDisplayMode)
        _maskAmountsByDefault = State(initialValue: initialMaskAmountsByDefault)
        _autoHideSeconds = State(initialValue: initialAutoHideSeconds)
        _hideOnLock = State(initialValue: initialHideOnLock)
        _maskOnAppSwitch = State(initialValue: initialMaskOnAppSwitch)
        _hideMenuBarOnBossKey = State(initialValue: initialHideMenuBarOnBossKey)
        _bossKey = State(initialValue: initialBossKey)
        _alwaysOnTop = State(initialValue: initialAlwaysOnTop)
        _storedAPIKey = State(initialValue: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("持仓组件")
                        .font(.system(size: 20, weight: .semibold))
                    Text("低调、隐私、只看仓位")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ConnectionBadge(state: store.connectionState)
            }
            .padding(.bottom, 16)

            Picker("设置分类", selection: $selectedTab) {
                Text("显示").tag(SettingsTab.display)
                Text("隐私").tag(SettingsTab.privacy)
                Text("账户").tag(SettingsTab.account)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 14)

            Group {
                switch selectedTab {
                case .display:
                    displayTab
                case .privacy:
                    privacyTab
                case .account:
                    accountTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(22)
        .frame(width: 520, height: 510)
        .onChange(of: opacityPercent) { _, value in onOpacityChanged(value) }
        .onChange(of: glassBlur) { _, value in onGlassBlurChanged(value) }
        .onChange(of: displayMode) { _, value in onDisplayModeChanged(value) }
        .onChange(of: alwaysOnTop) { _, value in onAlwaysOnTopChanged(value) }
        .onChange(of: maskAmountsByDefault) { _, value in WindowPreferences.shared.maskAmountsByDefault = value }
        .onChange(of: autoHideSeconds) { _, value in WindowPreferences.shared.autoHideSeconds = value }
        .onChange(of: hideOnLock) { _, value in WindowPreferences.shared.hideOnLock = value }
        .onChange(of: maskOnAppSwitch) { _, value in WindowPreferences.shared.maskOnAppSwitch = value }
        .onChange(of: hideMenuBarOnBossKey) { _, value in WindowPreferences.shared.hideMenuBarOnBossKey = value }
        .onChange(of: selectedTab) { _, tab in
            guard tab == .account else { return }
            storedAPIKey = KeychainService.shared.maskedAPIKey
        }
    }

    private var displayTab: some View {
        VStack(alignment: .leading, spacing: 15) {
            SettingsSectionTitle(title: "窗口")
            Picker("显示方式", selection: $displayMode) {
                ForEach(WidgetDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            SliderRow(title: "玻璃强度", value: $opacityPercent, range: 30...100, suffix: "%")
            SliderRow(title: "材质模糊", value: $glassBlur, range: 8...40, suffix: " px")

            ToggleRow(title: "始终置顶", subtitle: "关闭后仍可正常点击窗口", isOn: $alwaysOnTop)

            HStack {
                Text("窗口位置")
                Spacer()
                Button("恢复到右侧", action: onMoveToRight)
            }
            .padding(.top, 3)

            Text("顶部空白处拖动窗口；右侧按钮不会被拖拽区域拦截。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 9) {
            SettingsSectionTitle(title: "隐私保护")
            ToggleRow(title: "默认隐藏金额", subtitle: "关闭后启动时直接显示金额；需要时点顶部眼睛手动隐藏", isOn: $maskAmountsByDefault)
            ToggleRow(title: "切换应用时隐藏", subtitle: "离开组件后自动隐藏金额", isOn: $maskOnAppSwitch)
            ToggleRow(title: "锁屏时隐藏", subtitle: "锁屏或切换用户后保持隐藏", isOn: $hideOnLock)
            ToggleRow(title: "老板键时隐藏菜单栏图标", subtitle: "恢复仍使用快捷键", isOn: $hideMenuBarOnBossKey)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动隐藏时间")
                    Text("手动显示后自动恢复隐私；关闭则一直保持显示").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Stepper(autoHideSeconds == 0 ? "关闭" : "\(Int(autoHideSeconds)) 秒", value: $autoHideSeconds, in: 0...60, step: 1)
                    .labelsHidden()
                Text(autoHideSeconds == 0 ? "关闭" : "\(Int(autoHideSeconds)) 秒")
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 4)

            Divider().padding(.vertical, 4)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("老板键")
                    Text(bossKey.displayName).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(isRecordingBossKey ? "请按组合键…" : "更改") {
                    isRecordingBossKey = true
                }
                Button("立即测试", action: onToggleBossMode)
            }

            if isRecordingBossKey {
                HotkeyRecorderView(
                    isRecording: $isRecordingBossKey,
                    onCapture: { hotkey in
                        bossKey = hotkey
                        onBossKeyChanged(hotkey)
                        isRecordingBossKey = false
                        notice = "老板键已设置为 \(hotkey.displayName)"
                    },
                    onCancel: {
                        isRecordingBossKey = false
                    }
                )
                .frame(width: 1, height: 1)

                Text("按下包含 Control、Option、Command 或 Shift 的组合键；Esc 取消。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accountTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionTitle(title: "Binance USDⓈ-M")
            if isEditingCredentials {
                TextField("新的 API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                SecureField("新的 API Secret", text: $apiSecretInput)
                    .textFieldStyle(.roundedBorder)
                Text("仅使用读取权限；Secret 不会回填，也不会显示在界面上。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack {
                    Button(isWorking ? "连接中…" : "保存并测试") { testConnection() }
                        .disabled(isWorking || apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiSecretInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("取消") { cancelCredentialEdit() }
                }
            } else {
                HStack {
                    Circle().fill(store.connectionState.color).frame(width: 8, height: 8)
                    Text(store.connectionState.title)
                    Spacer()
                    Text("\(store.positions.count) 个持仓").foregroundStyle(.secondary)
                }
                if let storedAPIKey {
                    Text("API Key  \(storedAPIKey)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("尚未连接 Binance API")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("更换 API") {
                        apiKeyInput = ""
                        apiSecretInput = ""
                        isEditingCredentials = true
                    }
                    Button("删除凭证", role: .destructive) { deleteCredentials() }
                        .disabled(storedAPIKey == nil || isWorking)
                }
            }
            if let notice {
                Text(notice)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let lastError = store.lastError {
                Text(lastError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func testConnection() {
        isWorking = true
        notice = nil
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try await store.saveAndConnect(apiKey: apiKeyInput, apiSecret: apiSecretInput)
                storedAPIKey = KeychainService.shared.maskedAPIKey
                apiKeyInput = ""
                apiSecretInput = ""
                isEditingCredentials = false
                notice = "连接成功，凭证已保存到 macOS 钥匙串。"
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private func cancelCredentialEdit() {
        apiKeyInput = ""
        apiSecretInput = ""
        isEditingCredentials = false
    }

    private func deleteCredentials() {
        do {
            try store.deleteCredentials()
            storedAPIKey = nil
            notice = "凭证已从 macOS 钥匙串删除。"
        } catch {
            notice = error.localizedDescription
        }
    }
}

private struct SettingsSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: 1)
            Text("\(Int(value))\(suffix)")
                .monospacedDigit()
                .frame(width: 50, alignment: .trailing)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

private struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (GlobalHotkey) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyCaptureView {
        let view = HotkeyCaptureView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: HotkeyCaptureView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        guard isRecording else { return }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class HotkeyCaptureView: NSView {
    var onCapture: ((GlobalHotkey) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        guard let hotkey = GlobalHotkey.from(event: event) else {
            NSSound.beep()
            return
        }
        onCapture?(hotkey)
    }
}

private struct ConnectionBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor)
        }
    }

    private var title: String {
        switch state {
        case .live: return "已连接"
        case .mock: return "演示"
        case .notConfigured: return "未连接"
        default: return "连接异常"
        }
    }

    private var statusColor: Color {
        switch state {
        case .live, .mock: return .green
        default: return .red
        }
    }
}
