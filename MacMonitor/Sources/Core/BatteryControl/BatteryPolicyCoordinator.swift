import Combine
import Foundation

@MainActor
final class BatteryPolicyCoordinator: ObservableObject {
    @Published private(set) var state: BatteryControlState = .unavailable
    @Published private(set) var lastDecision: BatteryPolicyDecision?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var latestBatterySnapshot: BatterySnapshot = .unavailable
    @Published private(set) var recentEvents: [BatteryControlEvent] = []
    @Published private(set) var isInstallingHelper = false

    let settings: SettingsStore
    let controlService: BatteryControlService

    private let reconciliationManager: BatteryReconciliationManager
    private let safetyMonitor: BatteryControlSafetyMonitor
    private var hasStarted = false
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SettingsStore,
        controlService: BatteryControlService,
        reconciliationManager: BatteryReconciliationManager,
        safetyMonitor: BatteryControlSafetyMonitor = BatteryControlSafetyMonitor()
    ) {
        self.settings = settings
        self.controlService = controlService
        self.reconciliationManager = reconciliationManager
        self.safetyMonitor = safetyMonitor
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        controlService.$effectiveState
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)

        controlService.$recentEvents
            .sink { [weak self] events in
                guard let self else { return }
                recentEvents = events
                applySafetyMonitorIfNeeded(events: events)
            }
            .store(in: &cancellables)

        settings.$batteryPolicyConfiguration
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.reconcileNow(
                        source: .policy,
                        reason: "Policy configuration changed.",
                        force: true
                    )
                }
            }
            .store(in: &cancellables)

        controlService.refreshRecentEvents()
    }

    func stop() {
        hasStarted = false
        cancellables.removeAll()
    }

    func handle(snapshot: BatterySnapshot) async {
        latestBatterySnapshot = snapshot
        await reconcileNow(source: .policy, reason: "Telemetry updated.")
    }

    func handleLifecycleEvent(_ event: BatteryLifecycleEvent) async {
        let reason = "Lifecycle event: \(event.rawValue)."

        if event == .appDidLaunch {
            reconciliationManager.clearLastAppliedState()
        }

        let didApplyLifecycleOverride = await applyAdvancedLifecycleActions(for: event)
        if event == .willSleep && didApplyLifecycleOverride {
            return
        }
        await reconcileNow(source: .lifecycle, reason: reason, force: true)
    }

    func updateConfiguration(_ mutate: (inout BatteryPolicyConfiguration) -> Void) {
        var configuration = settings.batteryPolicyConfiguration
        mutate(&configuration)
        settings.batteryPolicyConfiguration = configuration.normalized()
    }

    func setAutomaticDischargeEnabled(_ enabled: Bool) {
        updateConfiguration { configuration in
            configuration.automaticDischargeEnabled = enabled
            if enabled {
                configuration.manualDischargeEnabled = false
            }
        }
    }

    func setManualDischargeEnabled(_ enabled: Bool) {
        updateConfiguration { configuration in
            configuration.manualDischargeEnabled = enabled
            if enabled {
                configuration.automaticDischargeEnabled = false
            }
        }
    }

    @discardableResult
    func applyScheduledAction(_ action: BatteryScheduledAction) async -> BatteryControlCommandResult {
        switch action {
        case .setChargeLimit(let limit):
            return await setChargeLimit(
                limit,
                source: .schedule,
                reason: "Scheduled charge limit update."
            )
        case .startTopUp:
            return await startTopUpNow(
                source: .schedule,
                reason: "Scheduled top up request."
            )
        case .startDischarge(let targetPercent):
            return await startDischargeNow(
                targetPercent: targetPercent,
                source: .schedule,
                reason: "Scheduled discharge request."
            )
        case .pauseCharging:
            return await pauseChargingNow(
                source: .schedule,
                reason: "Scheduled pause charging request."
            )
        }
    }

    @discardableResult
    func setChargeLimit(_ percent: Int) async -> BatteryControlCommandResult {
        await setChargeLimit(
            percent,
            source: .manual,
            reason: "Manual charge limit update."
        )
    }

    @discardableResult
    private func setChargeLimit(
        _ percent: Int,
        source: BatteryControlEventSource,
        reason: String
    ) async -> BatteryControlCommandResult {
        let normalizedLimit = min(max(percent, 50), 95)
        updateConfiguration { configuration in
            configuration.chargeLimitPercent = normalizedLimit
            configuration.manualDischargeEnabled = false
            configuration.topUpEnabled = false
        }

        return await directCommand(
            .setChargeLimit(normalizedLimit),
            state: .chargingToLimit,
            source: source,
            reason: reason
        )
    }

    @discardableResult
    func pauseChargingNow() async -> BatteryControlCommandResult {
        await pauseChargingNow(
            source: .manual,
            reason: "Manual pause charging request."
        )
    }

    @discardableResult
    private func pauseChargingNow(
        source: BatteryControlEventSource,
        reason: String
    ) async -> BatteryControlCommandResult {
        updateConfiguration { configuration in
            configuration.topUpEnabled = false
            configuration.manualDischargeEnabled = false
        }

        return await directCommand(
            .setChargingPaused(true),
            state: .pausedAtLimit,
            source: source,
            reason: reason
        )
    }

    @discardableResult
    func startChargingNow() async -> BatteryControlCommandResult {
        updateConfiguration { configuration in
            configuration.topUpEnabled = true
            configuration.manualDischargeEnabled = false
        }

        return await directCommand(
            .startTopUp,
            state: .topUp,
            source: .manual,
            reason: "Manual resume charging request."
        )
    }

    @discardableResult
    func startTopUpNow() async -> BatteryControlCommandResult {
        await startTopUpNow(
            source: .manual,
            reason: "Manual top up request."
        )
    }

    @discardableResult
    private func startTopUpNow(
        source: BatteryControlEventSource,
        reason: String
    ) async -> BatteryControlCommandResult {
        updateConfiguration { configuration in
            configuration.topUpEnabled = true
            configuration.manualDischargeEnabled = false
        }

        return await directCommand(
            .startTopUp,
            state: .topUp,
            source: source,
            reason: reason
        )
    }

    @discardableResult
    func startDischargeNow(targetPercent: Int) async -> BatteryControlCommandResult {
        await startDischargeNow(
            targetPercent: targetPercent,
            source: .manual,
            reason: "Manual discharge request."
        )
    }

    @discardableResult
    private func startDischargeNow(
        targetPercent: Int,
        source: BatteryControlEventSource,
        reason: String
    ) async -> BatteryControlCommandResult {
        let normalizedTarget = min(max(targetPercent, 50), 95)
        updateConfiguration { configuration in
            configuration.topUpEnabled = false
            configuration.manualDischargeEnabled = true
            configuration.automaticDischargeEnabled = false
            configuration.chargeLimitPercent = normalizedTarget
        }

        return await directCommand(
            .startDischarge(targetPercent: normalizedTarget),
            state: .dischargingToLimit,
            source: source,
            reason: reason
        )
    }

    @discardableResult
    func stopDischargeNow() async -> BatteryControlCommandResult {
        updateConfiguration { configuration in
            configuration.manualDischargeEnabled = false
        }

        return await directCommand(
            .stopDischarge,
            state: .pausedAtLimit,
            source: .manual,
            reason: "Manual stop discharge request."
        )
    }

    func statusText() -> String {
        let availabilityText: String
        switch controlService.availability {
        case .available:
            availabilityText = "Backend ready"
        case .unavailable(let reason):
            availabilityText = "Backend unavailable: \(reason)"
        }

        let percent = latestBatterySnapshot.percentage.map { "\($0)%" } ?? "--"
        let decisionText = lastDecision?.reason ?? "No policy decision yet."
        return "\(state.rawValue) • \(percent) • \(availabilityText) • \(decisionText)"
    }

    var helperAvailability: BatteryControlAvailability {
        controlService.availability
    }

    @discardableResult
    func installHelperIfNeeded() -> BatteryControlCommandResult {
        let result = controlService.installHelperIfNeeded()
        if result.accepted {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = result.message
        }
        return result
    }

    func installHelperIfNeededAsync() async {
        guard !isInstallingHelper else { return }
        isInstallingHelper = true
        defer { isInstallingHelper = false }

        let result = await controlService.installHelperIfNeededAsync()
        if result.accepted {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = result.message
        }
    }

    private func applySafetyMonitorIfNeeded(events: [BatteryControlEvent]) {
        let currentFlags = settings.batteryAdvancedControlFeatureFlags
        let adjustedFlags = safetyMonitor.applySafetyRules(events: events, currentFlags: currentFlags)

        guard adjustedFlags != currentFlags else { return }
        settings.batteryAdvancedControlFeatureFlags = adjustedFlags
        lastErrorMessage = safetyMonitor.lastAutoDisableReason
    }

    private func applyAdvancedLifecycleActions(for event: BatteryLifecycleEvent) async -> Bool {
        let flags = settings.batteryAdvancedControlFeatureFlags
        guard flags.anyEnabled else { return false }

        switch event {
        case .willSleep:
            let chargeLimit = settings.batteryPolicyConfiguration.chargeLimitPercent
            let shouldBlockSleepUntilLimit = flags.blockSleepUntilLimitEnabled
                && (latestBatterySnapshot.percentage ?? chargeLimit) < chargeLimit

            if shouldBlockSleepUntilLimit {
                let result = await directCommand(
                    .setChargeLimit(chargeLimit),
                    state: .chargingToLimit,
                    source: .lifecycle,
                    reason: "Advanced policy: block-sleep-until-limit requested."
                )
                return result.accepted
            } else if flags.sleepAwareStopChargingEnabled {
                let result = await directCommand(
                    .setChargingPaused(true),
                    state: .pausedAtLimit,
                    source: .lifecycle,
                    reason: "Advanced policy: sleep-aware stop charging."
                )
                return result.accepted
            }
        case .didWake:
            if flags.blockSleepUntilLimitEnabled {
                _ = await directCommand(
                    .setChargingPaused(false),
                    state: .chargingToLimit,
                    source: .lifecycle,
                    reason: "Advanced policy: wake resumed charging controls."
                )
            }
        case .appDidLaunch, .appWillTerminate, .userSessionDidBecomeActive, .userSessionDidResignActive:
            break
        }

        return false
    }

    private func reconcileNow(
        source: BatteryControlEventSource,
        reason: String,
        force: Bool = false
    ) async {
        let result = await reconciliationManager.reconcile(
            snapshot: latestBatterySnapshot,
            configuration: settings.batteryPolicyConfiguration,
            advancedFlags: settings.batteryAdvancedControlFeatureFlags,
            source: source,
            reason: reason,
            force: force
        )

        lastDecision = result.decision
        state = result.decision.state

        if let commandResult = result.commandResult, !commandResult.accepted {
            lastErrorMessage = commandResult.message
        } else {
            lastErrorMessage = nil
        }
    }

    private func directCommand(
        _ command: BatteryControlCommand,
        state: BatteryControlState,
        source: BatteryControlEventSource,
        reason: String
    ) async -> BatteryControlCommandResult {
        let result = await controlService.execute(
            command,
            resultingState: state,
            source: source,
            reason: reason,
            batteryPercent: latestBatterySnapshot.percentage
        )

        if result.accepted {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = result.message
        }

        return result
    }
}
