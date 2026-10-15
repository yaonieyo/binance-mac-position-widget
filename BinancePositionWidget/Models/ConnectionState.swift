import SwiftUI

enum ConnectionState: Equatable {
    case notConfigured
    case connecting
    case live
    case reconnecting
    case disconnected
    case authError(String)
    case mock

    var title: String {
        switch self {
        case .notConfigured: return "未连接"
        case .connecting: return "连接中"
        case .live: return "实时"
        case .reconnecting: return "重连中"
        case .disconnected: return "已断开"
        case .authError: return "认证失败"
        case .mock: return "Mock"
        }
    }

    var color: Color {
        switch self {
        case .notConfigured: return .secondary
        case .live, .mock: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected, .authError: return .red
        }
    }
}
