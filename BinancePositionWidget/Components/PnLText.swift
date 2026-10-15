import SwiftUI

struct PnLText: View {
    let value: Decimal
    let style: Font
    let showCurrency: Bool
    let isMasked: Bool

    init(value: Decimal, style: Font = .body, showCurrency: Bool = true, isMasked: Bool = false) {
        self.value = value
        self.style = style
        self.showCurrency = showCurrency
        self.isMasked = isMasked
    }

    var body: some View {
        Text(isMasked ? "••••" : (showCurrency ? NumberFormatterService.signedCurrency(value) : NumberFormatterService.signedPercent(value)))
            .font(style)
            .foregroundStyle(isMasked ? Color.secondary : (value >= 0 ? Color.green : Color.red))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }
}
