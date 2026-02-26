import XCTest
@testable import MacMonitor

final class BatteryScheduleEngineTests: XCTestCase {
    func testCoalescesDuplicateActionsByKeepingLatestTask() {
        let engine = BatteryScheduleEngine(queueCap: 8, staleTaskThreshold: 60 * 60)
        let base = Date(timeIntervalSince1970: 1_000_000)

        let first = BatteryScheduledTask(
            action: .setChargeLimit(80),
            scheduledAt: base.addingTimeInterval(-120),
            createdAt: base.addingTimeInterval(-120)
        )
        let second = BatteryScheduledTask(
            action: .setChargeLimit(80),
            scheduledAt: base.addingTimeInterval(-60),
            createdAt: base.addingTimeInterval(-60)
        )

        _ = engine.enqueueMissedTask(first, now: base)
        let result = engine.enqueueMissedTask(second, now: base)

        XCTAssertEqual(engine.queuedCount, 1)
        if case .replaced = result.disposition {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected replacement disposition")
        }

        let ready = engine.dequeueReadyTasks(now: base)
        XCTAssertEqual(ready.count, 1)
        XCTAssertEqual(ready.first?.id, second.id)
    }

    func testCapsQueueDepthByDroppingOldestEntries() {
        let engine = BatteryScheduleEngine(queueCap: 2, staleTaskThreshold: 60 * 60)
        let base = Date(timeIntervalSince1970: 2_000_000)

        let first = BatteryScheduledTask(action: .setChargeLimit(70), scheduledAt: base.addingTimeInterval(-180), createdAt: base.addingTimeInterval(-180))
        let second = BatteryScheduledTask(action: .startTopUp, scheduledAt: base.addingTimeInterval(-120), createdAt: base.addingTimeInterval(-120))
        let third = BatteryScheduledTask(action: .pauseCharging, scheduledAt: base.addingTimeInterval(-60), createdAt: base.addingTimeInterval(-60))

        _ = engine.enqueueMissedTask(first, now: base)
        _ = engine.enqueueMissedTask(second, now: base)
        _ = engine.enqueueMissedTask(third, now: base)

        XCTAssertEqual(engine.queuedCount, 2)
        let ready = engine.dequeueReadyTasks(now: base)
        XCTAssertEqual(ready.count, 2)
        XCTAssertFalse(ready.contains(where: { $0.id == first.id }))
        XCTAssertTrue(ready.contains(where: { $0.id == second.id }))
        XCTAssertTrue(ready.contains(where: { $0.id == third.id }))
    }

    func testDropsStaleTasksBeyondThreshold() {
        let engine = BatteryScheduleEngine(queueCap: 4, staleTaskThreshold: 300)
        let now = Date(timeIntervalSince1970: 3_000_000)
        let staleTask = BatteryScheduledTask(
            action: .startTopUp,
            scheduledAt: now.addingTimeInterval(-600),
            createdAt: now.addingTimeInterval(-600)
        )

        let result = engine.enqueueMissedTask(staleTask, now: now)

        XCTAssertEqual(result.disposition, .droppedAsStale)
        XCTAssertEqual(engine.queuedCount, 0)
    }

    func testDequeuesOnlyReadyTasks() {
        let engine = BatteryScheduleEngine(queueCap: 4, staleTaskThreshold: 60 * 60)
        let now = Date(timeIntervalSince1970: 4_000_000)

        let ready = BatteryScheduledTask(
            action: .pauseCharging,
            scheduledAt: now.addingTimeInterval(-60),
            createdAt: now.addingTimeInterval(-60)
        )
        let future = BatteryScheduledTask(
            action: .startDischarge(targetPercent: 75),
            scheduledAt: now.addingTimeInterval(600),
            createdAt: now.addingTimeInterval(-30)
        )

        _ = engine.enqueueMissedTask(ready, now: now)
        _ = engine.enqueueMissedTask(future, now: now)

        let dequeued = engine.dequeueReadyTasks(now: now)
        XCTAssertEqual(dequeued, [ready])
        XCTAssertEqual(engine.queuedCount, 1)
    }
}
