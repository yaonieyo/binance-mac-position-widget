import SwiftUI

struct PositionRow: View {
    let position: PositionItem
    let isMasked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(position.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(position.side.title) · \(position.leverage)X")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(position.side == .long ? Color.green : Color.red)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    PnLText(value: position.unrealizedPnL, style: .system(size: 14, weight: .semibold), isMasked: isMasked)
                    if let roi = position.roiPercent {
                        PnLText(value: roi, style: .system(size: 12, weight: .medium), showCurrency: false, isMasked: isMasked)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46, alignment: .leading)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PositionRowButtonStyle())
        .accessibilityLabel("查看 \(position.symbol) 持仓详情")
    }
}

private struct PositionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
