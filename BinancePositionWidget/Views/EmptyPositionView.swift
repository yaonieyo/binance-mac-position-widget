import SwiftUI

struct EmptyPositionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("暂无持仓")
                .font(.system(size: 17, weight: .semibold))
            Text("等待新的合约仓位")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
