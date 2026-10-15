import SwiftUI

struct PositionDetailPopover: View {
    let position: PositionItem
    let isMasked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.symbol)
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(position.side.title) · \(position.leverage)X")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(position.side == .long ? Color.green : Color.red)
                }
                Spacer()
                PnLText(value: position.unrealizedPnL, style: .system(size: 16, weight: .semibold), isMasked: isMasked)
            }

            Divider()
            detail("持仓", value: "\(NumberFormatterService.quantity(abs(position.positionAmount), symbol: position.symbol)) \(unit)", isSensitive: true)
            detail("开仓均价", value: NumberFormatterService.price(position.entryPrice), isSensitive: true)
            detail("标记价格", value: NumberFormatterService.price(position.markPrice), isSensitive: true)
            if let liquidationPrice = position.liquidationPrice {
                detail("强平价格", value: NumberFormatterService.price(liquidationPrice), isSensitive: true)
            }
            detail("未实现盈亏", value: NumberFormatterService.signedCurrency(position.unrealizedPnL), valueColor: position.unrealizedPnL >= 0 ? .green : .red, isSensitive: true)
            if let roi = position.roiPercent {
                detail("收益率", value: NumberFormatterService.signedPercent(roi), valueColor: roi >= 0 ? .green : .red, isSensitive: true)
            }
            if let marginType = position.marginType {
                detail("保证金模式", value: marginType.title)
            }
        }
        .padding(18)
        .frame(width: 260)
    }

    private var unit: String {
        if position.symbol.hasPrefix("BTC") { return "BTC" }
        if position.symbol.hasPrefix("ETH") { return "ETH" }
        return String(position.symbol.dropLast(4))
    }

    @ViewBuilder
    private func detail(_ label: String, value: String, valueColor: Color = .primary, isSensitive: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(isMasked && isSensitive ? "••••" : value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isMasked && isSensitive ? Color.secondary : valueColor)
                .monospacedDigit()
        }
    }
}
