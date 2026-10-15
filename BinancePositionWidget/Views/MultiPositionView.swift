import SwiftUI

struct MultiPositionView: View {
    let positions: [PositionItem]
    let totalPnL: Decimal
    let isMasked: Bool
    let onSelect: (PositionItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("总浮盈")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                PnLText(value: totalPnL, style: .system(size: 18, weight: .semibold), isMasked: isMasked)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text("\(positions.count)仓")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.bottom, 7)

            Divider()
                .opacity(0.6)
                .padding(.bottom, 7)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(positions) { position in
                        PositionRow(position: position, isMasked: isMasked) {
                            onSelect(position)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
