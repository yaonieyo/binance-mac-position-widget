import SwiftUI

struct MarketWatchlistView: View {
    let quotes: [MarketQuote]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自选行情")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if quotes.isEmpty {
                Text("正在连接行情…")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(quotes) { quote in
                    HStack(spacing: 8) {
                        Text(quote.symbol)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if let price = quote.displayPrice {
                            Text(NumberFormatterService.price(price))
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                        }
                        if let change = quote.changePercent {
                            Text(NumberFormatterService.signedPercent(change))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(change >= 0 ? Color.green : Color.red)
                                .monospacedDigit()
                                .frame(width: 68, alignment: .trailing)
                        }
                    }
                    .frame(minHeight: 23)
                }
            }
        }
    }
}

struct DesktopMarketWidgetView: View {
    let quotes: [MarketQuote]
    let glassOpacityPercent: Double

    @Environment(\.colorScheme) private var colorScheme

    private var visibleQuotes: [MarketQuote] {
        Array(quotes.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleQuotes.enumerated()), id: \.element.id) { index, quote in
                DesktopMarketRow(quote: quote)
                if index < visibleQuotes.count - 1 {
                    Divider()
                        .opacity(colorScheme == .dark ? 0.22 : 0.55)
                        .padding(.vertical, 2)
                }
            }

            if visibleQuotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("正在连接行情…")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Binance 公共市场数据")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(minWidth: 320, minHeight: 230, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.035)
                            : Color.white.opacity(0.12 * glassOpacityPercent / 100))
                }
        }
        .background {
            GlassBackgroundView(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 27)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.16), radius: 18, y: 8)
    }
}

private struct DesktopMarketRow: View {
    let quote: MarketQuote

    private var changeIsPositive: Bool {
        (quote.changePercent ?? 0) >= 0
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: changeIsPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(changeIsPositive ? .green : .red)
                    Text(shortSymbol)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                }
                Text(displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(quote.displayPrice.map(NumberFormatterService.price) ?? "—")
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let change = quote.changePercent {
                    Text(NumberFormatterService.signedPercent(change))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(change >= 0 ? .green : .red)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54)
    }

    private var shortSymbol: String {
        quote.symbol.replacingOccurrences(of: "USDT", with: "-USD")
    }

    private var displayName: String {
        switch quote.symbol {
        case "BTCUSDT": return "Bitcoin USD"
        case "ETHUSDT": return "Ethereum USD"
        case "BNBUSDT": return "BNB USD"
        case "SOLUSDT": return "Solana USD"
        default: return quote.symbol
        }
    }
}
