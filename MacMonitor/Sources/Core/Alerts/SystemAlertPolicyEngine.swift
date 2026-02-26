import Foundation

enum SystemAlertKind: String, Codable, Equatable, CaseIterable {
    case thermal
    case storage
    case batteryHealth
}

struct SystemAlert: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let kind: SystemAlertKind
    let title: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date,
        kind: SystemAlertKind,
        title: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.title = title
        self.message = message
    }
}

struct SystemAlertPolicyEngine {
    func evaluate(
        snapshot: SystemSnapshot,
        history: [SystemSnapshot],
        settings: SystemAlertSettings,
        referenceDate: Date = Date()
    ) -> [SystemAlert] {
        let normalizedSettings = settings.normalized()
        var alerts: [SystemAlert] = []

        if normalizedSettings.thermalAlertEnabled,
           snapshot.thermal.state != .unknown,
           snapshot.thermal.state.severity >= normalizedSettings.thermalThreshold.severity {
            alerts.append(
                SystemAlert(
                    timestamp: referenceDate,
                    kind: .thermal,
                    title: "Thermal Pressure \(snapshot.thermal.state.title)",
                    message: "System thermal state reached \(snapshot.thermal.state.title)."
                )
            )
        }

        if normalizedSettings.storageAlertEnabled {
            let storagePercent = snapshot.storage.usageRatio * 100
            if storagePercent >= Double(normalizedSettings.storageUsagePercentThreshold) {
                alerts.append(
                    SystemAlert(
                        timestamp: referenceDate,
                        kind: .storage,
                        title: "Storage Usage High",
                        message: "Storage usage is \(Int(storagePercent.rounded()))%."
                    )
                )
            }
        }

        if normalizedSettings.batteryHealthDropAlertEnabled,
           let currentHealth = snapshot.battery.healthPercent {
            let healthValues = history.compactMap(\.battery.healthPercent)
            let bestRecordedHealth = healthValues.max() ?? currentHealth
            let drop = bestRecordedHealth - currentHealth
            if drop >= normalizedSettings.batteryHealthDropPercentThreshold {
                alerts.append(
                    SystemAlert(
                        timestamp: referenceDate,
                        kind: .batteryHealth,
                        title: "Battery Health Changed",
                        message: "Battery health dropped by \(drop)% from recorded peak \(bestRecordedHealth)%."
                    )
                )
            }
        }

        return alerts
    }
}
