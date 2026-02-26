import Foundation

@MainActor
final class BatteryReconciliationManager {
    struct Result {
        let decision: BatteryPolicyDecision
        let commandResult: BatteryControlCommandResult?
        let commandApplied: Bool
    }

    private struct Signature: Hashable {
        let state: BatteryControlState
        let command: BatteryControlCommand?
    }

    private let policyEngine: BatteryPolicyEngine
    private let controlService: BatteryControlService
    private var lastAppliedSignature: Signature?

    init(
        policyEngine: BatteryPolicyEngine,
        controlService: BatteryControlService
    ) {
        self.policyEngine = policyEngine
        self.controlService = controlService
    }

    func reconcile(
        snapshot: BatterySnapshot,
        configuration: BatteryPolicyConfiguration,
        advancedFlags: BatteryAdvancedControlFeatureFlags = .default,
        source: BatteryControlEventSource,
        reason: String,
        force: Bool = false
    ) async -> Result {
        let decision = policyEngine.evaluate(
            snapshot: snapshot,
            configuration: configuration,
            advancedFlags: advancedFlags
        )
        let signature = Signature(state: decision.state, command: decision.command)
        let shouldApply = force || signature != lastAppliedSignature
        let batteryPercent = snapshot.percentage

        var commandResult: BatteryControlCommandResult?
        if let command = decision.command, shouldApply {
            commandResult = await controlService.execute(
                command,
                resultingState: decision.state,
                source: source,
                reason: "\(reason) \(decision.reason)",
                batteryPercent: batteryPercent
            )
        } else if shouldApply {
            controlService.recordState(
                decision.state,
                source: source,
                reason: "\(reason) \(decision.reason)",
                batteryPercent: batteryPercent
            )
        }

        if shouldApply && (commandResult == nil || commandResult?.accepted == true) {
            lastAppliedSignature = signature
        }

        return Result(
            decision: decision,
            commandResult: commandResult,
            commandApplied: shouldApply
        )
    }

    func clearLastAppliedState() {
        lastAppliedSignature = nil
    }
}
