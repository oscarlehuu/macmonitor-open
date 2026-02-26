import Foundation

struct RAMPolicyBreach: Equatable {
    let policy: RAMPolicy
    let usage: AppRAMUsage
    let thresholdBytes: UInt64
    let observedBytes: UInt64
    let triggerKind: RAMPolicyTriggerKind
}

final class RAMPolicyEvaluator {
    private struct PolicyState {
        var firstExceededAt: Date?
        var lastNotifiedImmediateAt: Date?
        var lastNotifiedSustainedAt: Date?
    }

    private var states: [UUID: PolicyState] = [:]

    func evaluate(
        policies: [RAMPolicy],
        usageByBundleID: [String: AppRAMUsage],
        totalMemoryBytes: UInt64,
        now: Date
    ) -> [RAMPolicyBreach] {
        let activePolicyIDs = Set(policies.map(\.id))
        states = states.filter { activePolicyIDs.contains($0.key) }

        var breaches: [RAMPolicyBreach] = []

        for policy in policies.map(\.normalized) where policy.enabled {
            var state = states[policy.id, default: PolicyState()]
            let threshold = policy.thresholdBytes(totalMemoryBytes: totalMemoryBytes)

            guard let usage = usageByBundleID[policy.bundleID], usage.usedBytes > threshold else {
                state.firstExceededAt = nil
                states[policy.id] = state
                continue
            }

            if state.firstExceededAt == nil {
                state.firstExceededAt = now
            }

            let elapsed = now.timeIntervalSince(state.firstExceededAt ?? now)
            let sustainedReached = elapsed >= TimeInterval(policy.sustainedSeconds)

            let triggerKind: RAMPolicyTriggerKind?
            if policy.triggerMode.includesSustained, sustainedReached {
                triggerKind = .sustained
            } else if policy.triggerMode.includesImmediate {
                triggerKind = .immediate
            } else {
                triggerKind = nil
            }

            guard let triggerKind else {
                states[policy.id] = state
                continue
            }

            let lastNotifiedAt: Date?
            switch triggerKind {
            case .immediate:
                lastNotifiedAt = state.lastNotifiedImmediateAt
            case .sustained:
                lastNotifiedAt = state.lastNotifiedSustainedAt
            }

            if let lastNotifiedAt,
               now.timeIntervalSince(lastNotifiedAt) < TimeInterval(policy.notifyCooldownSeconds) {
                states[policy.id] = state
                continue
            }

            let breach = RAMPolicyBreach(
                policy: policy,
                usage: usage,
                thresholdBytes: threshold,
                observedBytes: usage.usedBytes,
                triggerKind: triggerKind
            )
            breaches.append(breach)

            switch triggerKind {
            case .immediate:
                state.lastNotifiedImmediateAt = now
            case .sustained:
                state.lastNotifiedSustainedAt = now
            }
            states[policy.id] = state
        }

        return breaches
    }
}
