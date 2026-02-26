import XCTest
@testable import MacMonitor

@MainActor
final class BatteryPolicyCoordinatorTests: XCTestCase {
    func testSetChargeLimitClampsToValidatedBoundsAndSendsCommand() async {
        let context = makeContext()
        context.coordinator.start()
        await context.coordinator.handle(snapshot: makeSnapshot(percent: 60))

        let result = await context.coordinator.setChargeLimit(120)

        XCTAssertTrue(result.accepted)
        XCTAssertEqual(context.settings.batteryPolicyConfiguration.chargeLimitPercent, 95)
        XCTAssertEqual(context.backend.executedCommands.last, .setChargeLimit(95))
    }

    func testStartDischargeUpdatesPolicyAndSendsCommand() async {
        let context = makeContext()
        context.coordinator.start()
        await context.coordinator.handle(snapshot: makeSnapshot(percent: 90))

        let result = await context.coordinator.startDischargeNow(targetPercent: 70)

        XCTAssertTrue(result.accepted)
        XCTAssertTrue(context.settings.batteryPolicyConfiguration.manualDischargeEnabled)
        XCTAssertEqual(context.settings.batteryPolicyConfiguration.chargeLimitPercent, 70)
        XCTAssertEqual(context.backend.executedCommands.last, .startDischarge(targetPercent: 70))
    }

    func testEnablingManualDischargeTurnsOffAutomaticDischarge() {
        let context = makeContext()
        context.coordinator.start()
        context.coordinator.updateConfiguration { configuration in
            configuration.automaticDischargeEnabled = true
            configuration.manualDischargeEnabled = false
        }

        context.coordinator.setManualDischargeEnabled(true)

        XCTAssertTrue(context.settings.batteryPolicyConfiguration.manualDischargeEnabled)
        XCTAssertFalse(context.settings.batteryPolicyConfiguration.automaticDischargeEnabled)
    }

    func testEnablingAutomaticDischargeTurnsOffManualDischarge() {
        let context = makeContext()
        context.coordinator.start()
        context.coordinator.updateConfiguration { configuration in
            configuration.manualDischargeEnabled = true
            configuration.automaticDischargeEnabled = false
        }

        context.coordinator.setAutomaticDischargeEnabled(true)

        XCTAssertTrue(context.settings.batteryPolicyConfiguration.automaticDischargeEnabled)
        XCTAssertFalse(context.settings.batteryPolicyConfiguration.manualDischargeEnabled)
    }

    func testLifecycleWakeForcesPolicyReplay() async {
        let context = makeContext()
        var config = context.settings.batteryPolicyConfiguration
        config.chargeLimitPercent = 80
        context.settings.batteryPolicyConfiguration = config

        context.coordinator.start()
        await context.coordinator.handle(snapshot: makeSnapshot(percent: 70))
        let firstCommandCount = context.backend.executedCommands.count

        await context.coordinator.handleLifecycleEvent(.didWake)

        XCTAssertEqual(context.backend.executedCommands.count, firstCommandCount + 1)
        XCTAssertEqual(context.backend.executedCommands.last, .setChargeLimit(80))
    }

    func testSleepAwareWillSleepDoesNotImmediatelyReconcileAwayPause() async {
        let context = makeContext()
        var config = context.settings.batteryPolicyConfiguration
        config.chargeLimitPercent = 80
        context.settings.batteryPolicyConfiguration = config

        var flags = context.settings.batteryAdvancedControlFeatureFlags
        flags.sleepAwareStopChargingEnabled = true
        context.settings.batteryAdvancedControlFeatureFlags = flags

        context.coordinator.start()
        await context.coordinator.handle(snapshot: makeSnapshot(percent: 60))
        let firstCommandCount = context.backend.executedCommands.count

        await context.coordinator.handleLifecycleEvent(.willSleep)

        XCTAssertEqual(context.backend.executedCommands.count, firstCommandCount + 1)
        XCTAssertEqual(context.backend.executedCommands.last, .setChargingPaused(true))
    }

    func testStartChargingStartsTopUpAndClearsManualDischarge() async {
        let context = makeContext()
        context.coordinator.start()
        context.coordinator.updateConfiguration { configuration in
            configuration.manualDischargeEnabled = true
        }

        let result = await context.coordinator.startChargingNow()

        XCTAssertTrue(result.accepted)
        XCTAssertTrue(context.settings.batteryPolicyConfiguration.topUpEnabled)
        XCTAssertFalse(context.settings.batteryPolicyConfiguration.manualDischargeEnabled)
        XCTAssertEqual(context.backend.executedCommands.last, .startTopUp)
    }

    func testPauseChargingClearsTopUpAndManualDischarge() async {
        let context = makeContext()
        context.coordinator.start()
        context.coordinator.updateConfiguration { configuration in
            configuration.topUpEnabled = true
            configuration.manualDischargeEnabled = true
        }

        let result = await context.coordinator.pauseChargingNow()

        XCTAssertTrue(result.accepted)
        XCTAssertFalse(context.settings.batteryPolicyConfiguration.topUpEnabled)
        XCTAssertFalse(context.settings.batteryPolicyConfiguration.manualDischargeEnabled)
        XCTAssertEqual(context.backend.executedCommands.last, .setChargingPaused(true))
    }

    func testInstallHelperRefreshesAvailability() {
        let context = makeContext()
        context.backend.availability = .unavailable(reason: "not installed")
        context.backend.installResult = .success("installed")
        context.coordinator.start()

        let result = context.coordinator.installHelperIfNeeded()

        XCTAssertTrue(result.accepted)
        if case .available = context.coordinator.helperAvailability {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected helper availability to become available after install.")
        }
    }

    private func makeContext() -> (
        coordinator: BatteryPolicyCoordinator,
        settings: SettingsStore,
        backend: CoordinatorRecordingBackend
    ) {
        let defaults = UserDefaults(suiteName: "BatteryPolicyCoordinatorTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults, launchAtLoginManager: CoordinatorLaunchManager())
        let backend = CoordinatorRecordingBackend()
        let eventStore = CoordinatorInMemoryEventStore()
        let service = BatteryControlService(backend: backend, eventStore: eventStore)
        let manager = BatteryReconciliationManager(
            policyEngine: BatteryPolicyEngine(),
            controlService: service
        )

        let coordinator = BatteryPolicyCoordinator(
            settings: settings,
            controlService: service,
            reconciliationManager: manager
        )

        return (coordinator, settings, backend)
    }

    private func makeSnapshot(percent: Int) -> BatterySnapshot {
        BatterySnapshot(
            currentCapacity: percent,
            maxCapacity: 100,
            isPresent: true,
            isCharging: false,
            isCharged: false,
            powerSource: .battery,
            timeToEmptyMinutes: nil,
            timeToFullChargeMinutes: nil,
            amperageMilliAmps: nil,
            voltageMilliVolts: nil,
            temperatureCelsius: nil,
            cycleCount: nil,
            health: nil,
            healthCondition: nil,
            lowPowerModeEnabled: false
        )
    }
}

private struct CoordinatorLaunchManager: LaunchAtLoginManaging {
    func isEnabled() -> Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

private final class CoordinatorRecordingBackend: BatteryControlBackend {
    var availability: BatteryControlAvailability = .available
    var executedCommands: [BatteryControlCommand] = []
    var installResult: BatteryControlCommandResult = .success()

    func execute(_ command: BatteryControlCommand) -> BatteryControlCommandResult {
        executedCommands.append(command)
        return .success()
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        if installResult.accepted {
            availability = .available
        }
        return installResult
    }
}

private final class CoordinatorInMemoryEventStore: BatteryEventStoring {
    private var events: [BatteryControlEvent] = []

    func append(_ event: BatteryControlEvent) throws {
        events.append(event)
    }

    func recentEvents(limit: Int) -> [BatteryControlEvent] {
        Array(events.suffix(limit))
    }

    func pruneExpiredEvents(referenceDate: Date) {
        // no-op for tests
    }
}
