import Foundation

enum BatteryScheduledAction: Codable, Equatable, Hashable {
    case setChargeLimit(Int)
    case startTopUp
    case startDischarge(targetPercent: Int)
    case pauseCharging
}

struct BatteryScheduledTask: Codable, Equatable, Identifiable {
    let id: UUID
    let action: BatteryScheduledAction
    let scheduledAt: Date
    let createdAt: Date

    init(
        id: UUID = UUID(),
        action: BatteryScheduledAction,
        scheduledAt: Date,
        createdAt: Date
    ) {
        self.id = id
        self.action = action
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
    }
}

enum BatteryTaskEnqueueDisposition: Equatable {
    case enqueued
    case replaced(taskID: UUID)
    case droppedAsStale
}

struct BatteryTaskEnqueueResult: Equatable {
    let disposition: BatteryTaskEnqueueDisposition
    let queueDepth: Int
}

final class BatteryScheduleEngine {
    private var queuedTasks: [BatteryScheduledTask] = []
    private let queueCap: Int
    private let staleTaskThreshold: TimeInterval

    init(queueCap: Int = 32, staleTaskThreshold: TimeInterval = 60 * 60 * 12) {
        self.queueCap = max(1, queueCap)
        self.staleTaskThreshold = max(60, staleTaskThreshold)
    }

    var queuedCount: Int {
        queuedTasks.count
    }

    func enqueueMissedTask(_ task: BatteryScheduledTask, now: Date = Date()) -> BatteryTaskEnqueueResult {
        if now.timeIntervalSince(task.scheduledAt) > staleTaskThreshold {
            return BatteryTaskEnqueueResult(disposition: .droppedAsStale, queueDepth: queuedTasks.count)
        }

        if let index = queuedTasks.firstIndex(where: { $0.action == task.action }) {
            let replacedTaskID = queuedTasks[index].id
            queuedTasks[index] = task
            sortQueue()
            return BatteryTaskEnqueueResult(
                disposition: .replaced(taskID: replacedTaskID),
                queueDepth: queuedTasks.count
            )
        }

        queuedTasks.append(task)
        sortQueue()

        while queuedTasks.count > queueCap {
            queuedTasks.removeFirst()
        }

        return BatteryTaskEnqueueResult(disposition: .enqueued, queueDepth: queuedTasks.count)
    }

    func dequeueReadyTasks(now: Date = Date()) -> [BatteryScheduledTask] {
        guard !queuedTasks.isEmpty else { return [] }

        let ready = queuedTasks.filter { $0.scheduledAt <= now }
        queuedTasks.removeAll { $0.scheduledAt <= now }
        return ready.sorted { lhs, rhs in
            if lhs.scheduledAt == rhs.scheduledAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.scheduledAt < rhs.scheduledAt
        }
    }

    private func sortQueue() {
        queuedTasks.sort { lhs, rhs in
            if lhs.scheduledAt == rhs.scheduledAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.scheduledAt < rhs.scheduledAt
        }
    }
}
