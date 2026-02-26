import XCTest
@testable import MacMonitor

@MainActor
final class BatteryReconciliationManagerTests: XCTestCase {
    func testReconcileAppliesCommandOnFirstEvaluation() async {
        let context = makeContext()
        var configuration = BatteryPolicyConfiguration.default
        configuration.chargeLimitPercent = 80

        let result = await context.manager.reconcile(
            snapshot: makeSnapshot(percent: 70),
            configuration: configuration,
            source: .policy,
            reason: "test",
            force: false
        )

        XCTAssertTrue(result.commandApplied)
        XCTAssertEqual(result.decision.state, .chargingToLimit)
        XCTAssertEqual(context.backend.executedCommands, [.setChargeLimit(80)])
    }

    func testReconcileSkipsDuplicateCommandWhenNotForced() async {
        let context = makeContext()
        var configuration = BatteryPolicyConfiguration.default
        configuration.chargeLimitPercent = 80

        _ = await context.manager.reconcile(
            snapshot: makeSnapshot(percent: 70),
            configuration: configuration,
            source: .policy,
            reason: "first",
            force: false
        )

        let second = await context.manager.reconcile(
            snapshot: makeSnapshot(percent: 70),
            configuration: configuration,
            source: .policy,
            reason: "second",
            force: false
        )

        XCTAssertFalse(second.commandApplied)
        XCTAssertEqual(context.backend.executedCommands.count, 1)
    }

    func testReconcileReappliesDuplicateCommandWhenForced() async {
        let context = makeContext()
        var configuration = BatteryPolicyConfiguration.default
        configuration.chargeLimitPercent = 80

        _ = await context.manager.reconcile(
            snapshot: makeSnapshot(percent: 70),
            configuration: configuration,
            source: .policy,
            reason: "first",
            force: false
        )

        let second = await context.manager.reconcile(
            snapshot: makeSnapshot(percent: 70),
            configuration: configuration,
            source: .lifecycle,
            reason: "wake",
            force: true
        )

        XCTAssertTrue(second.commandApplied)
        XCTAssertEqual(context.backend.executedCommands.count, 2)
        XCTAssertEqual(context.backend.executedCommands.last, .setChargeLimit(80))
    }

    private func makeContext() -> (manager: BatteryReconciliationManager, backend: RecordingBatteryBackend) {
        let backend = RecordingBatteryBackend()
        let eventStore = InMemoryBatteryEventStore()
        let service = BatteryControlService(backend: backend, eventStore: eventStore)
        let manager = BatteryReconciliationManager(
            policyEngine: BatteryPolicyEngine(),
            controlService: service
        )
        return (manager, backend)
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

private final class RecordingBatteryBackend: BatteryControlBackend {
    var availability: BatteryControlAvailability = .available
    var executedCommands: [BatteryControlCommand] = []
    var result: BatteryControlCommandResult = .success()

    func execute(_ command: BatteryControlCommand) -> BatteryControlCommandResult {
        executedCommands.append(command)
        return result
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        .success()
    }
}

private final class InMemoryBatteryEventStore: BatteryEventStoring {
    private(set) var events: [BatteryControlEvent] = []

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
