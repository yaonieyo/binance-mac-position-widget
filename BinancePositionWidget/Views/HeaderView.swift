import SwiftUI

struct HeaderView: View {
    let state: ConnectionState
    let positionCount: Int
    let isAlwaysOnTop: Bool
    let isMasked: Bool
    let onToggleMask: () -> Void
    let onFitHeight: () -> Void
    let onToggleAlwaysOnTop: () -> Void
    let onReloadSnapshot: () -> Void
    let onSetDemoScenario: (MockScenario?) -> Void
    let onShowSettings: () -> Void
    let onHideWindow: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            HStack(spacing: 7) {
                Text("持仓")
                    .font(.system(size: 15, weight: .medium))
                Text(statusTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)
            }

            Spacer(minLength: 8)

            HeaderIconButton(
                systemName: isMasked ? "eye.slash" : "eye",
                accessibilityLabel: isMasked ? "显示金额" : "隐藏金额",
                action: onToggleMask
            )
            HeaderIconButton(
                systemName: isAlwaysOnTop ? "pin.fill" : "pin",
                isActive: isAlwaysOnTop,
                accessibilityLabel: isAlwaysOnTop ? "取消置顶" : "始终置顶",
                action: onToggleAlwaysOnTop
            )

            Menu {
                Button("设置…", action: onShowSettings)
                Button("重新读取", action: onReloadSnapshot)
                Button("自动调整高度", action: onFitHeight)
                Menu("演示预览") {
                    ForEach(MockScenario.allCases, id: \.rawValue) { scenario in
                        Button(scenario.title) {
                            onSetDemoScenario(scenario)
                        }
                    }
                    Divider()
                    Button("返回真实账户", action: { onSetDemoScenario(nil) })
                }
                Divider()
                Button(isAlwaysOnTop ? "取消置顶" : "始终置顶", action: onToggleAlwaysOnTop)
                Button("隐藏窗口", action: onHideWindow)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("更多操作")
        }
        .frame(height: 30)
        .foregroundStyle(.primary)
    }

    private var statusTitle: String {
        switch state {
        case .live:
            return "已连接"
        case .mock:
            return "演示"
        case .notConfigured:
            return "未连接"
        case .connecting, .reconnecting:
            return "更新中"
        default:
            return "连接异常"
        }
    }

    private var statusColor: Color {
        switch state {
        case .live, .mock:
            return .green
        case .connecting, .reconnecting:
            return .orange
        default:
            return .red
        }
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    var isActive = false
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 30, height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
    }
}
