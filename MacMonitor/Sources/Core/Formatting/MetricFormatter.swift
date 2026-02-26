import Foundation

enum MetricFormatter {
    private static func makeByteFormatter() -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        return formatter
    }

    private static func makePercentFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }

    private static func makeDataRateFormatter() -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        return formatter
    }

    private static func makeRelativeFormatter() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }

    static func bytes(_ value: UInt64) -> String {
        makeByteFormatter().string(fromByteCount: Int64(value))
    }

    static func usage(used: UInt64, total: UInt64) -> String {
        "\(bytes(used)) / \(bytes(total))"
    }

    static func percent(used: UInt64, total: UInt64) -> String {
        guard total > 0 else { return "0%" }
        let ratio = Double(used) / Double(total)
        let nsNumber = NSNumber(value: ratio)
        return makePercentFormatter().string(from: nsNumber) ?? "0%"
    }

    static func thermalText(for state: ThermalState) -> String {
        state.title
    }

    static func relativeTime(from date: Date, reference: Date = Date()) -> String {
        makeRelativeFormatter().localizedString(for: date, relativeTo: reference)
    }

    static func bytesPerSecond(_ value: Double?) -> String {
        guard let value else { return "--/s" }
        let sanitized = Int64(max(0, value).rounded())
        return "\(makeDataRateFormatter().string(fromByteCount: sanitized))/s"
    }

    static func percentValue(_ value: Double?) -> String {
        guard let value else { return "--" }
        let clamped = min(max(value, 0), 100)
        return "\(Int(clamped.rounded()))%"
    }
}
