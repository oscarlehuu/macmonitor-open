import AppIntents
import Foundation

enum TrendSummaryWindowIntent: String, AppEnum {
    case last24Hours
    case last7Days

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Trend Window")
    static let caseDisplayRepresentations: [TrendSummaryWindowIntent: DisplayRepresentation] = [
        .last24Hours: "Last 24 Hours",
        .last7Days: "Last 7 Days"
    ]
}

struct SetBatteryChargeLimitIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Battery Charge Limit"
    static let description = IntentDescription("Set MacMonitor battery charge limit between 50% and 95%.")

    @Parameter(title: "Charge Limit (%)")
    var chargeLimit: Int

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard (50...95).contains(chargeLimit) else {
            return .result(value: "Charge limit must be between 50 and 95 percent.")
        }

        let response = await BatteryIntentBridge.shared.perform(.setChargeLimit(chargeLimit))
        return .result(value: response.message)
    }
}

struct PauseBatteryChargingIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Battery Charging"
    static let description = IntentDescription("Pause charging immediately.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = await BatteryIntentBridge.shared.perform(.pauseCharging)
        return .result(value: response.message)
    }
}

struct StartBatteryTopUpIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Battery Top Up"
    static let description = IntentDescription("Temporarily charge battery to full.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = await BatteryIntentBridge.shared.perform(.startTopUp)
        return .result(value: response.message)
    }
}

struct StartBatteryDischargeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Battery Discharge"
    static let description = IntentDescription("Discharge battery down to a target between 50% and 95%.")

    @Parameter(title: "Target (%)")
    var targetPercent: Int

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard (50...95).contains(targetPercent) else {
            return .result(value: "Target must be between 50 and 95 percent.")
        }

        let response = await BatteryIntentBridge.shared.perform(.startDischarge(targetPercent))
        return .result(value: response.message)
    }
}

struct GetBatteryControlStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Battery Control State"
    static let description = IntentDescription("Return current battery control state and diagnostics.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = await BatteryIntentBridge.shared.perform(.getState)
        return .result(value: response.message)
    }
}

struct GetMacMonitorStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get MacMonitor Status"
    static let description = IntentDescription("Return read-only summary metrics from the latest shared snapshot.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = AppGroupSnapshotStore()
        guard let summary = store.loadSummary() else {
            return .result(value: "No shared snapshot available yet.")
        }

        let latest = summary.latest
        let batteryText = latest.batteryPercent.map { "\($0)%" } ?? "Unavailable"
        let cpuText = latest.cpuUsagePercent.map { "\(Int($0.rounded()))%" } ?? "--"
        let result = [
            "Thermal: \(latest.thermalState.title)",
            "RAM: \(Int(latest.memoryUsagePercent.rounded()))%",
            "Storage: \(Int(latest.storageUsagePercent.rounded()))%",
            "CPU: \(cpuText)",
            "Battery: \(batteryText)"
        ].joined(separator: " | ")
        return .result(value: result)
    }
}

struct GetMacMonitorTrendSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get MacMonitor Trend Summary"
    static let description = IntentDescription("Return read-only trend averages from shared snapshots.")
    static let openAppWhenRun = false

    @Parameter(title: "Window", default: .last24Hours)
    var window: TrendSummaryWindowIntent

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = AppGroupSnapshotStore()
        guard let summary = store.loadSummary() else {
            return .result(value: "No trend data available yet.")
        }

        let points: [SharedSnapshotPoint]
        switch window {
        case .last24Hours:
            points = summary.trend24Hours
        case .last7Days:
            points = summary.trend7Days
        }

        guard !points.isEmpty else {
            return .result(value: "No trend samples available for this window.")
        }

        let memoryAverage = points.map(\.memoryUsagePercent).reduce(0, +) / Double(points.count)
        let storageAverage = points.map(\.storageUsagePercent).reduce(0, +) / Double(points.count)
        let cpuValues = points.compactMap(\.cpuUsagePercent)
        let cpuAverage = cpuValues.isEmpty ? nil : cpuValues.reduce(0, +) / Double(cpuValues.count)

        let cpuText = cpuAverage.map { "\(Int($0.rounded()))%" } ?? "--"
        let trendText = "Trend \(window.rawValue): RAM avg \(Int(memoryAverage.rounded()))%, Storage avg \(Int(storageAverage.rounded()))%, CPU avg \(cpuText), Samples \(points.count)."
        return .result(value: trendText)
    }
}

struct BatteryAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetBatteryChargeLimitIntent(),
            phrases: [
                "Set \(.applicationName) battery limit",
                "Adjust battery limit in \(.applicationName)"
            ],
            shortTitle: "Set Limit",
            systemImageName: "battery.75"
        )

        AppShortcut(
            intent: PauseBatteryChargingIntent(),
            phrases: [
                "Pause charging with \(.applicationName)",
                "Pause battery charging in \(.applicationName)"
            ],
            shortTitle: "Pause Charging",
            systemImageName: "pause.circle"
        )

        AppShortcut(
            intent: StartBatteryTopUpIntent(),
            phrases: [
                "Top up battery with \(.applicationName)",
                "Start battery top up in \(.applicationName)"
            ],
            shortTitle: "Top Up",
            systemImageName: "arrow.up.circle"
        )

        AppShortcut(
            intent: StartBatteryDischargeIntent(),
            phrases: [
                "Start battery discharge with \(.applicationName)",
                "Discharge battery in \(.applicationName)"
            ],
            shortTitle: "Discharge",
            systemImageName: "arrow.down.circle"
        )

        AppShortcut(
            intent: GetBatteryControlStateIntent(),
            phrases: [
                "Get battery state from \(.applicationName)",
                "Check battery state in \(.applicationName)"
            ],
            shortTitle: "Battery State",
            systemImageName: "battery.100"
        )

        AppShortcut(
            intent: GetMacMonitorStatusIntent(),
            phrases: [
                "Get status from \(.applicationName)",
                "Read system status in \(.applicationName)"
            ],
            shortTitle: "Status",
            systemImageName: "chart.bar"
        )

        AppShortcut(
            intent: GetMacMonitorTrendSummaryIntent(),
            phrases: [
                "Get trend summary from \(.applicationName)",
                "Read trends in \(.applicationName)"
            ],
            shortTitle: "Trend Summary",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
    }
}
