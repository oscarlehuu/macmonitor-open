import XCTest
@testable import MacMonitor

@MainActor
final class BatteryScheduleViewModelTests: XCTestCase {
    func testScheduleDraftTaskRejectsTimeTooSoon() async {
        let now = Date(timeIntervalSince1970: 6_000_000)
        let context = await makeContext(now: { now })

        context.viewModel.draftScheduledAt = now.addingTimeInterval(30)
        let scheduled = context.viewModel.scheduleDraftTask()

        XCTAssertFalse(scheduled)
        XCTAssertEqual(context.viewModel.errorMessage, "Choose a time at least 1 minute in the future.")
        XCTAssertTrue(context.viewModel.pendingTasks.isEmpty)
    }

    func testScheduleDraftTaskRejectsOutOfRangeTargetPercent() async {
        let now = Date(timeIntervalSince1970: 6_100_000)
        let context = await makeContext(now: { now })

        context.viewModel.draftAction = .startDischarge
        context.viewModel.draftTargetPercent = 40
        context.viewModel.draftScheduledAt = now.addingTimeInterval(600)

        let scheduled = context.viewModel.scheduleDraftTask()

        XCTAssertFalse(scheduled)
        XCTAssertEqual(context.viewModel.errorMessage, "Target percent must be between 50% and 95%.")
        XCTAssertTrue(context.viewModel.pendingTasks.isEmpty)
    }

    func testScheduleDraftTaskKeepsPendingTasksSortedByExecutionTime() async {
        let now = Date(timeIntervalSince1970: 6_200_000)
        let context = await makeContext(now: { now })

        context.viewModel.draftAction = .pauseCharging
        context.viewModel.draftScheduledAt = now.addingTimeInterval(900)
        XCTAssertTrue(context.viewModel.scheduleDraftTask())

        context.viewModel.draftAction = .setChargeLimit
        context.viewModel.draftTargetPercent = 78
        context.viewModel.draftScheduledAt = now.addingTimeInterval(300)
        XCTAssertTrue(context.viewModel.scheduleDraftTask())

        XCTAssertEqual(context.viewModel.pendingTasks.count, 2)
        XCTAssertEqual(context.viewModel.pendingTasks.map(\.action), [.setChargeLimit(78), .pauseCharging])
        XCTAssertEqual(context.store.tasks.map(\.action), [.setChargeLimit(78), .pauseCharging])
    }

    func testLastFailureReasonTracksMostRecentFailedEvent() async {
        let now = Date(timeIntervalSince1970: 6_300_000)
        let context = await makeContext(now: { now })
        context.backend.nextResult = .failure("helper unavailable")

        let result = await context.policyCoordinator.applyScheduledAction(.pauseCharging)
        XCTAssertFalse(result.accepted)
        await Task.yield()

        XCTAssertTrue(context.viewModel.lastFailureReason?.contains("helper unavailable") ?? false)
    }

    private func makeContext(
        now: @escaping () -> Date
    ) async -> (
        viewModel: BatteryScheduleViewModel,
        scheduleCoordinator: BatteryScheduleCoordinator,
        policyCoordinator: BatteryPolicyCoordinator,
        store: InMemoryBatteryScheduleStore,
        backend: ScheduleViewModelBackend
    ) {
        let defaults = UserDefaults(suiteName: "BatteryScheduleViewModelTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults, launchAtLoginManager: ScheduleViewModelLaunchManager())
        let backend = ScheduleViewModelBackend()
        let eventStore = ScheduleViewModelEventStore()
        let service = BatteryControlService(backend: backend, eventStore: eventStore, now: now)
        let manager = BatteryReconciliationManager(policyEngine: BatteryPolicyEngine(), controlService: service)
        let policyCoordinator = BatteryPolicyCoordinator(
            settings: settings,
            controlService: service,
            reconciliationManager: manager
        )
        policyCoordinator.start()
        await policyCoordinator.handle(snapshot: makeSnapshot(percent: 80))

        let store = InMemoryBatteryScheduleStore()
        let queueEngine = BatteryScheduleEngine(queueCap: 16, staleTaskThreshold: 60 * 60)
        let scheduleCoordinator = BatteryScheduleCoordinator(
            store: store,
            queueEngine: queueEngine,
            policyCoordinator: policyCoordinator,
            checkInterval: 3600,
            now: now
        )
        let viewModel = BatteryScheduleViewModel(
            scheduleCoordinator: scheduleCoordinator,
            policyCoordinator: policyCoordinator,
            minimumLeadTime: 60,
            defaultLeadTime: 300,
            now: now
        )

        return (viewModel, scheduleCoordinator, policyCoordinator, store, backend)
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

private struct ScheduleViewModelLaunchManager: LaunchAtLoginManaging {
    func isEnabled() -> Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

private final class ScheduleViewModelBackend: BatteryControlBackend {
    var availability: BatteryControlAvailability = .available
    var nextResult: BatteryControlCommandResult = .success()
    private(set) var executedCommands: [BatteryControlCommand] = []

    func execute(_ command: BatteryControlCommand) -> BatteryControlCommandResult {
        executedCommands.append(command)
        return nextResult
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        .success()
    }
}

private final class ScheduleViewModelEventStore: BatteryEventStoring {
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

private final class InMemoryBatteryScheduleStore: BatteryScheduleStoring {
    var tasks: [BatteryScheduledTask] = []

    func loadTasks() -> [BatteryScheduledTask] {
        tasks
    }

    func saveTasks(_ tasks: [BatteryScheduledTask]) throws {
        self.tasks = tasks
    }
}
