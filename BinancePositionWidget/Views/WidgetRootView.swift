import SwiftUI

struct WidgetRootView: View {
    @ObservedObject var store: PositionStore
    @ObservedObject var privacyController: PrivacyController
    let onPositionCountChanged: (Int) -> Void
    let onFitHeight: () -> Void
    let onToggleAlwaysOnTop: () -> Void
    let onDisplayModeChanged: (WidgetDisplayMode) -> Void
    let onToggleMask: () -> Void
    let onHideWindow: () -> Void
    let onSetDemoScenario: (MockScenario?) -> Void
    let initialAlwaysOnTop: Bool
    let initialDisplayMode: WidgetDisplayMode
    let glassOpacityPercent: Double
    let glassBlur: Double
    let onReloadSnapshot: () -> Void
    let onShowSettings: () -> Void

    @State private var selectedPosition: PositionItem?
    @State private var isAlwaysOnTop: Bool
    @State private var displayMode: WidgetDisplayMode
    @Environment(\.colorScheme) private var colorScheme

    init(
        store: PositionStore,
        privacyController: PrivacyController,
        onPositionCountChanged: @escaping (Int) -> Void,
        onFitHeight: @escaping () -> Void,
        onToggleAlwaysOnTop: @escaping () -> Void,
        onDisplayModeChanged: @escaping (WidgetDisplayMode) -> Void,
        onToggleMask: @escaping () -> Void,
        onHideWindow: @escaping () -> Void,
        onSetDemoScenario: @escaping (MockScenario?) -> Void,
        isAlwaysOnTop: Bool,
        displayMode: WidgetDisplayMode,
        glassOpacityPercent: Double,
        glassBlur: Double,
        onReloadSnapshot: @escaping () -> Void,
        onShowSettings: @escaping () -> Void
    ) {
        self.store = store
        self.privacyController = privacyController
        self.onPositionCountChanged = onPositionCountChanged
        self.onFitHeight = onFitHeight
        self.onToggleAlwaysOnTop = onToggleAlwaysOnTop
        self.onDisplayModeChanged = onDisplayModeChanged
        self.onToggleMask = onToggleMask
        self.onHideWindow = onHideWindow
        self.onSetDemoScenario = onSetDemoScenario
        self.initialAlwaysOnTop = isAlwaysOnTop
        self.initialDisplayMode = displayMode
        self.glassOpacityPercent = glassOpacityPercent
        self.glassBlur = glassBlur
        self.onReloadSnapshot = onReloadSnapshot
        self.onShowSettings = onShowSettings
        _isAlwaysOnTop = State(initialValue: isAlwaysOnTop)
        _displayMode = State(initialValue: displayMode)
    }

    var body: some View {
        Group {
            if displayMode == .desktopMarket {
                DesktopMarketWidgetView(quotes: store.marketQuotes, glassOpacityPercent: glassOpacityPercent)
            } else {
                positionPanel
            }
        }
        .onChange(of: store.positions.count) { _, newValue in
            onPositionCountChanged(newValue)
        }
        .onChange(of: store.connectionState) { _, _ in
            onPositionCountChanged(store.positions.count)
        }
        .onAppear {
            onPositionCountChanged(store.positions.count)
        }
        .popover(item: $selectedPosition, arrowEdge: .trailing) { position in
            PositionDetailPopover(position: position, isMasked: privacyController.isMasked)
        }
    }

    private var positionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                state: store.connectionState,
                positionCount: store.positions.count,
                isAlwaysOnTop: isAlwaysOnTop,
                isMasked: privacyController.isMasked,
                onToggleMask: onToggleMask,
                onFitHeight: onFitHeight,
                onToggleAlwaysOnTop: {
                    isAlwaysOnTop.toggle()
                    onToggleAlwaysOnTop()
                },
                onReloadSnapshot: onReloadSnapshot,
                onSetDemoScenario: onSetDemoScenario,
                onShowSettings: onShowSettings,
                onHideWindow: onHideWindow
            )
            .padding(.bottom, 6)

            Group {
                if store.connectionState == .notConfigured {
                    NotConfiguredView(
                        quotes: store.marketQuotes,
                        lastError: store.lastError,
                        onShowSettings: onShowSettings
                    )
                } else if store.positions.isEmpty {
                    EmptyAccountView(
                        quotes: store.marketQuotes,
                        lastError: store.lastError
                    )
                } else if store.positions.count == 1, let position = store.positions.first {
                    SinglePositionView(position: position, isMasked: privacyController.isMasked)
                } else {
                    MultiPositionView(
                        positions: store.positions,
                        totalPnL: store.totalUnrealizedPnL,
                        isMasked: privacyController.isMasked,
                        onSelect: { selectedPosition = $0 }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(minWidth: 200, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity, alignment: .topLeading)
        .background {
            GlassBackgroundView(
                material: glassBlur >= 22 ? .hudWindow : .underWindowBackground,
                blendingMode: .behindWindow,
                cornerRadius: 24
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.035)
                    : Color.white.opacity(0.12 * glassOpacityPercent / 100))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.07), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
    }
}

private struct NotConfiguredView: View {
    let quotes: [MarketQuote]
    let lastError: String?
    let onShowSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("还没有连接账户")
                .font(.system(size: 20, weight: .semibold))
            Text("连接只读 API 后，在这里查看持仓和实时浮盈。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("设置 Binance API", action: onShowSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

            MarketWatchlistView(quotes: quotes)
            ErrorText(lastError)
        }
    }
}

private struct EmptyAccountView: View {
    let quotes: [MarketQuote]
    let lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            EmptyPositionView()
            MarketWatchlistView(quotes: quotes)
            ErrorText(lastError)
        }
    }
}

private struct ErrorText: View {
    let error: String?

    init(_ error: String?) {
        self.error = error
    }

    var body: some View {
        if let error {
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(.red.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
