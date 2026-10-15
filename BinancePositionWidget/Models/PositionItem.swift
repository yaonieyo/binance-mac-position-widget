import Foundation

enum PositionSide: String, CaseIterable, Codable {
    case long
    case short

    var title: String {
        switch self {
        case .long: return "多"
        case .short: return "空"
        }
    }
}

enum MarginType: String, Codable {
    case cross
    case isolated

    var title: String {
        switch self {
        case .cross: return "全仓"
        case .isolated: return "逐仓"
        }
    }
}

struct PositionItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let side: PositionSide

    let positionAmount: Decimal
    let leverage: Int
    let entryPrice: Decimal
    var markPrice: Decimal
    let liquidationPrice: Decimal?

    var unrealizedPnL: Decimal
    var roiPercent: Decimal?

    let marginType: MarginType?
    let positionInitialMargin: Decimal?

    var updatedAt: Date
}
