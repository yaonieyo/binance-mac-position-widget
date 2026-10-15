import SwiftUI

struct SinglePositionView: View {
    let position: PositionItem
    let isMasked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(position.side.title)
                        Text("·")
                        Text("\(position.leverage)X")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(position.side == .long ? Color.green : Color.red)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("浮盈")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    PnLText(
                        value: position.unrealizedPnL,
                        style: .system(size: 19, weight: .semibold),
                        isMasked: isMasked
                    )
                    if let roi = position.roiPercent {
                        PnLText(
                            value: roi,
                            style: .system(size: 12, weight: .medium),
                            showCurrency: false,
                            isMasked: isMasked
                        )
                    }
                }
            }

            Divider()
                .opacity(0.45)

            HStack(spacing: 0) {
                Metric(label: "开仓价", value: NumberFormatterService.price(position.entryPrice), isMasked: isMasked)
                Metric(label: "当前价", value: NumberFormatterService.price(position.markPrice), isMasked: isMasked)
                Metric(
                    label: "持仓",
                    value: "\(NumberFormatterService.quantity(abs(position.positionAmount), symbol: position.symbol)) \(quantityUnit)",
                    isMasked: isMasked
                )
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var quantityUnit: String {
        position.symbol.hasPrefix("BTC") ? "BTC" : (position.symbol.hasPrefix("ETH") ? "ETH" : "\(position.symbol.dropLast(4))")
    }
}

private struct Metric: View {
    let label: String
    let value: String
    let isMasked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(isMasked ? "••••" : value)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
