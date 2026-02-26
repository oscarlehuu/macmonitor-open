import Foundation

enum BatteryAdvancedControlFeature: String, CaseIterable, Codable, Identifiable {
    case sleepAwareStopCharging
    case blockSleepUntilLimit
    case calibrationWorkflow
    case hardwarePercentageRefinement
    case magsafeLEDControl

    var id: String { rawValue }
}

@MainActor
final class BatteryControlSafetyMonitor: ObservableObject {
    @Published private(set) var autoDisabledFeatures: Set<BatteryAdvancedControlFeature> = []
    @Published private(set) var lastAutoDisableReason: String?

    private let failureThreshold: Int
    private let failureWindow: TimeInterval

    init(failureThreshold: Int = 3, failureWindow: TimeInterval = 30 * 60) {
        self.failureThreshold = max(1, failureThreshold)
        self.failureWindow = max(60, failureWindow)
    }

    func applySafetyRules(
        events: [BatteryControlEvent],
        currentFlags: BatteryAdvancedControlFeatureFlags,
        now: Date = Date()
    ) -> BatteryAdvancedControlFeatureFlags {
        guard currentFlags.anyEnabled else {
            autoDisabledFeatures = []
            lastAutoDisableReason = nil
            return currentFlags
        }

        let recentFailures = events.filter {
            !$0.accepted && now.timeIntervalSince($0.timestamp) <= failureWindow
        }

        guard recentFailures.count >= failureThreshold else {
            return currentFlags
        }

        var updated = currentFlags
        var disabled: Set<BatteryAdvancedControlFeature> = []

        let lifecycleFailureCount = recentFailures.filter { $0.source == .lifecycle }.count
        if lifecycleFailureCount >= failureThreshold {
            if updated.sleepAwareStopChargingEnabled {
                updated.sleepAwareStopChargingEnabled = false
                disabled.insert(.sleepAwareStopCharging)
            }
            if updated.blockSleepUntilLimitEnabled {
                updated.blockSleepUntilLimitEnabled = false
                disabled.insert(.blockSleepUntilLimit)
            }
        }

        let calibrationFailures = recentFailures.filter { $0.message.localizedCaseInsensitiveContains("calibration") }
        if calibrationFailures.count >= failureThreshold, updated.calibrationWorkflowEnabled {
            updated.calibrationWorkflowEnabled = false
            disabled.insert(.calibrationWorkflow)
        }

        let hardwareRefinementFailures = recentFailures.filter {
            $0.message.localizedCaseInsensitiveContains("percentage refinement")
        }
        if hardwareRefinementFailures.count >= failureThreshold, updated.hardwarePercentageRefinementEnabled {
            updated.hardwarePercentageRefinementEnabled = false
            disabled.insert(.hardwarePercentageRefinement)
        }

        let magsafeFailures = recentFailures.filter { $0.message.localizedCaseInsensitiveContains("magsafe") }
        if magsafeFailures.count >= failureThreshold, updated.magsafeLEDControlEnabled {
            updated.magsafeLEDControlEnabled = false
            disabled.insert(.magsafeLEDControl)
        }

        if !disabled.isEmpty {
            autoDisabledFeatures.formUnion(disabled)
            lastAutoDisableReason = "Auto-disabled \(disabled.count) advanced feature(s) after repeated failures."
        }

        return updated
    }
}
