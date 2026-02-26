import XCTest
@testable import MacMonitor

@MainActor
final class BatteryScheduleCoordinatorTests: XCTestCase {
    func testStartupExecutesDueTasksAndPersistsFutureTasks() async {
        let now = Date(timeIntervalSince1970: 5_000_000)
        let context = await makeContext(now: { now }, staleTaskThreshold: 60 * 60)

        let dueTask = BatteryScheduledTask(
            action: .setChargeLimit(80),
            scheduledAt: now.addingTimeInterval(-120),
            createdAt: now.addingTimeInterval(-120)
        )
        let futureTask = BatteryScheduledTask(
            action: .pauseCharging,
            scheduledAt: now.addingTimeInterval(600),
            createdAt: now.addingTimeInterval(-30)
        )
        context.store.tasks = [dueTask, futureTask]

        await context.scheduleCoordinator.start()

        XCTAssertEqual(context.backend.executedCommands, [.setChargeLimit(80)])
        XCTAssertEqual(context.scheduleCoordinator.pendingTasks.map(\.id), [futureTask.id])
        XCTAssertEqual(context.store.tasks.map(\.id), [futureTask.id])

        context.scheduleCoordinator.stop()
    }

    func testStartupDropsStaleTasks() async {
        let now = Date(timeIntervalSince1970: 5_100_000)
        let context = await makeContext(now: { now }, staleTaskThreshold: 60)

        let staleTask = BatteryScheduledTask(
            action: .startTopUp,
            scheduledAt: now.addingTimeInterval(-600),
            createdAt: now.addingTimeInterval(-600)
        )
        context.store.tasks = [staleTask]

        await context.scheduleCoordinator.start()

        XCTAssertTrue(context.backend.executedCommands.isEmpty)
        XCTAssertTrue(context.scheduleCoordinator.pendingTasks.isEmpty)
        XCTAssertTrue(context.store.tasks.isEmpty)
        XCTAssertTrue(context.scheduleCoordinator.lastExecutionMessage?.contains("stale dropped 1") ?? false)

        context.scheduleCoordinator.stop()
    }

    private func makeContext(
        now: @escaping () -> Date,
        staleTaskThreshold: TimeInterval
    ) async -> (
        scheduleCoordinator: BatteryScheduleCoordinator,
        store: MemoryBatteryScheduleStore,
        backend: ScheduleCoordinatorBackend
    ) {
        let defaults = UserDefaults(suiteName: "BatteryScheduleCoordinatorTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults, launchAtLoginManager: ScheduleLaunchManager())

        let backend = ScheduleCoordinatorBackend()
        let eventStore = ScheduleEventStore()
        let service = BatteryControlService(backend: backend, eventStore: eventStore, now: now)
        let manager = BatteryReconciliationManager(policyEngine: BatteryPolicyEngine(), controlService: service)
        let policyCoordinator = BatteryPolicyCoordinator(
            settings: settings,
            controlService: service,
            reconciliationManager: manager
        )
        policyCoordinator.start()
        await policyCoordinator.handle(snapshot: makeSnapshot(percent: 80))

        let store = MemoryBatteryScheduleStore()
        let queueEngine = BatteryScheduleEngine(queueCap: 32, staleTaskThreshold: staleTaskThreshold)

        let scheduleCoordinator = BatteryScheduleCoordinator(
            store: store,
            queueEngine: queueEngine,
            policyCoordinator: policyCoordinator,
            checkInterval: 3600,
            now: now
        )

        return (scheduleCoordinator, store, backend)
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

private struct ScheduleLaunchManager: LaunchAtLoginManaging {
    func isEnabled() -> Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

private final class ScheduleCoordinatorBackend: BatteryControlBackend {
    var availability: BatteryControlAvailability = .available
    private(set) var executedCommands: [BatteryControlCommand] = []

    func execute(_ command: BatteryControlCommand) -> BatteryControlCommandResult {
        executedCommands.append(command)
        return .success()
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        .success()
    }
}

private final class ScheduleEventStore: BatteryEventStoring {
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

private final class MemoryBatteryScheduleStore: BatteryScheduleStoring {
    var tasks: [BatteryScheduledTask] = []

    func loadTasks() -> [BatteryScheduledTask] {
        tasks
    }

    func saveTasks(_ tasks: [BatteryScheduledTask]) throws {
        self.tasks = tasks
    }
}
