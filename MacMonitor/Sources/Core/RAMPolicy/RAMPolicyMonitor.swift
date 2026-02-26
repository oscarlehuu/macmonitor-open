import Combine
import Foundation

@MainActor
protocol RAMPolicyMonitoring: AnyObject {
    func evaluateNow()
}

@MainActor
final class RAMPolicyMonitor: RAMPolicyMonitoring {
    private let policyStore: RAMPolicyStoring
    private let eventStore: RAMPolicyEventStoring
    private let usageCollector: RunningAppRAMCollecting
    private let evaluator: RAMPolicyEvaluator
    private let notifier: RAMPolicyNotifying
    private let totalMemoryProvider: () -> UInt64
    private let now: () -> Date
    private let sampleInterval: TimeInterval

    private var timerCancellable: AnyCancellable?
    private var hasStarted = false

    init(
        policyStore: RAMPolicyStoring,
        eventStore: RAMPolicyEventStoring,
        usageCollector: RunningAppRAMCollecting,
        evaluator: RAMPolicyEvaluator,
        notifier: RAMPolicyNotifying,
        sampleInterval: TimeInterval = 5,
        totalMemoryProvider: @escaping () -> UInt64 = { ProcessInfo.processInfo.physicalMemory },
        now: @escaping () -> Date = Date.init
    ) {
        self.policyStore = policyStore
        self.eventStore = eventStore
        self.usageCollector = usageCollector
        self.evaluator = evaluator
        self.notifier = notifier
        self.sampleInterval = sampleInterval
        self.totalMemoryProvider = totalMemoryProvider
        self.now = now
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        eventStore.pruneExpiredEvents(referenceDate: now())
        evaluateNow()

        timerCancellable = Timer.publish(every: sampleInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateNow()
            }
    }

    func stop() {
        hasStarted = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func evaluateNow() {
        let policies = policyStore.loadPolicies().filter(\.enabled)
        guard !policies.isEmpty else { return }

        do {
            let usages = try usageCollector.collectUsageByApp()
            let usageMap = Dictionary(uniqueKeysWithValues: usages.map { ($0.bundleID, $0) })
            let timestamp = now()

            let breaches = evaluator.evaluate(
                policies: policies,
                usageByBundleID: usageMap,
                totalMemoryBytes: totalMemoryProvider(),
                now: timestamp
            )

            guard !breaches.isEmpty else { return }

            for breach in breaches {
                notifier.notify(breach: breach)

                let event = RAMPolicyEvent(
                    timestamp: timestamp,
                    policyID: breach.policy.id,
                    bundleID: breach.policy.bundleID,
                    displayName: breach.policy.displayName,
                    observedBytes: breach.observedBytes,
                    thresholdBytes: breach.thresholdBytes,
                    triggerKind: breach.triggerKind,
                    message: "\(breach.policy.displayName) used \(MetricFormatter.bytes(breach.observedBytes)) (limit \(MetricFormatter.bytes(breach.thresholdBytes)))."
                )

                try? eventStore.append(event)
            }
        } catch {
            // Keep monitor resilient if process collection fails transiently.
        }
    }
}
