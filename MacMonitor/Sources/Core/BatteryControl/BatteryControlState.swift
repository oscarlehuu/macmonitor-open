import Foundation

enum BatteryControlState: String, Codable, Equatable {
    case unavailable
    case chargingToLimit
    case pausedAtLimit
    case dischargingToLimit
    case topUp
    case heatProtection
    case sailing
}

struct BatteryPolicyConfiguration: Codable, Equatable {
    var chargeLimitPercent: Int
    var automaticDischargeEnabled: Bool
    var manualDischargeEnabled: Bool
    var sailingModeEnabled: Bool
    var sailingLowerPercent: Int
    var sailingUpperPercent: Int
    var topUpEnabled: Bool
    var heatProtectionEnabled: Bool
    var heatProtectionThresholdCelsius: Int

    static let `default` = BatteryPolicyConfiguration(
        chargeLimitPercent: 80,
        automaticDischargeEnabled: false,
        manualDischargeEnabled: false,
        sailingModeEnabled: false,
        sailingLowerPercent: 75,
        sailingUpperPercent: 80,
        topUpEnabled: false,
        heatProtectionEnabled: false,
        heatProtectionThresholdCelsius: 35
    )

    func normalized() -> BatteryPolicyConfiguration {
        let clampedChargeLimit = min(max(chargeLimitPercent, 50), 95)
        let clampedLower = min(max(sailingLowerPercent, 50), 95)
        let clampedUpper = min(max(sailingUpperPercent, 50), 95)
        let lower = min(clampedLower, clampedUpper)
        let upper = max(clampedLower, clampedUpper)
        // Manual mode has higher priority than automatic mode in policy evaluation.
        // Normalize to a single active discharge mode to keep settings consistent.
        let manualEnabled = manualDischargeEnabled
        let automaticEnabled = automaticDischargeEnabled && !manualEnabled
        return BatteryPolicyConfiguration(
            chargeLimitPercent: clampedChargeLimit,
            automaticDischargeEnabled: automaticEnabled,
            manualDischargeEnabled: manualEnabled,
            sailingModeEnabled: sailingModeEnabled,
            sailingLowerPercent: lower,
            sailingUpperPercent: upper,
            topUpEnabled: topUpEnabled,
            heatProtectionEnabled: heatProtectionEnabled,
            heatProtectionThresholdCelsius: max(20, min(55, heatProtectionThresholdCelsius))
        )
    }
}

struct BatteryPolicyDecision: Equatable {
    let state: BatteryControlState
    let command: BatteryControlCommand?
    let reason: String
}
