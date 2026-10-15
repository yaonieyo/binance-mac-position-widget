import SwiftUI

struct StatusDot: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(state.color)
                .frame(width: 6, height: 6)
            Text(state.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("连接状态：\(state.title)")
    }
}
