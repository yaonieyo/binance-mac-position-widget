import Foundation
import SwiftUI

struct MarketQuote: Identifiable, Equatable {
    let symbol: String
    var lastPrice: Decimal?
    var markPrice: Decimal?
    var changePercent: Decimal?
    var updatedAt: Date

    var id: String { symbol }

    var displayPrice: Decimal? {
        markPrice ?? lastPrice
    }
}

enum MarketStreamState: Equatable {
    case connecting
    case live
    case reconnecting
    case disconnected

    var title: String {
        switch self {
        case .connecting: return "行情连接中"
        case .live: return "行情实时"
        case .reconnecting: return "行情重连中"
        case .disconnected: return "行情断开"
        }
    }

    var color: Color {
        switch self {
        case .live: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected: return .red
        }
    }
}
