import Combine
import Foundation

@MainActor
final class BatteryScheduleCoordinator: ObservableObject {
    @Published private(set) var pendingTasks: [BatteryScheduledTask] = []
    @Published private(set) var lastExecutionMessage: String?

    private let store: BatteryScheduleStoring
    private let queueEngine: BatteryScheduleEngine
    private let policyCoordinator: BatteryPolicyCoordinator
    private let now: () -> Date
    private let checkInterval: TimeInterval

    private var timerCancellable: AnyCancellable?
    private var hasStarted = false

    init(
        store: BatteryScheduleStoring,
        queueEngine: BatteryScheduleEngine,
        policyCoordinator: BatteryPolicyCoordinator,
        checkInterval: TimeInterval = 30,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.queueEngine = queueEngine
        self.policyCoordinator = policyCoordinator
        self.checkInterval = checkInterval
        self.now = now
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        pendingTasks = store.loadTasks()
        await processMissedAndReadyTasks(trigger: "startup")

        timerCancellable = Timer.publish(every: checkInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.processMissedAndReadyTasks(trigger: "timer")
                }
            }
    }

    func stop() {
        hasStarted = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func schedule(action: BatteryScheduledAction, at scheduledAt: Date) {
        let task = BatteryScheduledTask(
            action: action,
            scheduledAt: scheduledAt,
            createdAt: now()
        )

        pendingTasks.append(task)
        pendingTasks.sort { lhs, rhs in
            if lhs.scheduledAt == rhs.scheduledAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.scheduledAt < rhs.scheduledAt
        }
        persistPendingTasks()
    }

    func cancel(taskID: UUID) {
        pendingTasks.removeAll { $0.id == taskID }
        persistPendingTasks()
    }

    func processWakeCatchUp() {
        Task { [weak self] in
            await self?.processMissedAndReadyTasks(trigger: "wake")
        }
    }

    private func processMissedAndReadyTasks(trigger: String) async {
        let referenceDate = now()
        var futureTasks: [BatteryScheduledTask] = []

        var staleDroppedCount = 0
        var replacedCount = 0

        for task in pendingTasks {
            if task.scheduledAt <= referenceDate {
                let enqueueResult = queueEngine.enqueueMissedTask(task, now: referenceDate)
                switch enqueueResult.disposition {
                case .droppedAsStale:
                    staleDroppedCount += 1
                case .replaced:
                    replacedCount += 1
                case .enqueued:
                    break
                }
            } else {
                futureTasks.append(task)
            }
        }

        pendingTasks = futureTasks
        persistPendingTasks()

        let readyTasks = queueEngine.dequeueReadyTasks(now: referenceDate)
        guard !readyTasks.isEmpty || staleDroppedCount > 0 || replacedCount > 0 else {
            return
        }

        await execute(tasks: readyTasks, trigger: trigger, staleDroppedCount: staleDroppedCount, replacedCount: replacedCount)
    }

    private func execute(
        tasks: [BatteryScheduledTask],
        trigger: String,
        staleDroppedCount: Int,
        replacedCount: Int
    ) async {
        var failedCount = 0

        for task in tasks {
            let result = await policyCoordinator.applyScheduledAction(task.action)
            if !result.accepted {
                failedCount += 1
            }
        }

        let executedCount = tasks.count - failedCount
        lastExecutionMessage = "\(trigger): executed \(executedCount), failed \(failedCount), stale dropped \(staleDroppedCount), coalesced \(replacedCount)"
    }

    private func persistPendingTasks() {
        do {
            try store.saveTasks(pendingTasks)
        } catch {
            lastExecutionMessage = "Failed to persist battery schedule tasks."
        }
    }
}
