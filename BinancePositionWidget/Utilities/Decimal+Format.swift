import Foundation

enum NumberFormatterService {
    static func signedCurrency(_ value: Decimal, currency: String = "USDT") -> String {
        "\(signed(value, fractionDigits: 2)) \(currency)"
    }

    static func signedPercent(_ value: Decimal) -> String {
        "\(signed(value, fractionDigits: 2))%"
    }

    static func price(_ value: Decimal) -> String {
        let absolute = NSDecimalNumber(decimal: abs(value)).doubleValue
        let digits: Int
        if absolute >= 1000 { digits = 1 }
        else if absolute >= 1 { digits = 2 }
        else if absolute >= 0.1 { digits = 4 }
        else { digits = 6 }
        return plain(value, fractionDigits: digits)
    }

    static func quantity(_ value: Decimal, symbol: String) -> String {
        let digits = symbol.hasPrefix("BTC") ? 4 : (abs(NSDecimalNumber(decimal: value).doubleValue) < 1 ? 4 : 2)
        return plain(value, fractionDigits: digits)
    }

    private static func signed(_ value: Decimal, fractionDigits: Int) -> String {
        let number = NSDecimalNumber(decimal: value).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.positivePrefix = "+"
        formatter.negativePrefix = "-"
        return formatter.string(from: NSNumber(value: number)) ?? "0.00"
    }

    private static func plain(_ value: Decimal, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }
}
