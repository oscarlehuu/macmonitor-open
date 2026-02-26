import XCTest
@testable import MacMonitor

final class BatteryEventStoreTests: XCTestCase {
    func testRetentionKeepsOnlyRecentBatteryEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BatteryEventStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let store = FileBatteryEventStore(directoryURL: directory, retentionDays: 1)
        let now = Date()
        let oldTimestamp = now.addingTimeInterval(-(2 * 24 * 60 * 60))

        try store.append(
            BatteryControlEvent(
                timestamp: oldTimestamp,
                source: .policy,
                state: .chargingToLimit,
                command: .setChargeLimit(80),
                accepted: true,
                message: "old",
                batteryPercent: 70
            )
        )

        try store.append(
            BatteryControlEvent(
                timestamp: now,
                source: .manual,
                state: .pausedAtLimit,
                command: .setChargingPaused(true),
                accepted: true,
                message: "recent",
                batteryPercent: 80
            )
        )

        let events = store.recentEvents(limit: 10)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.message, "recent")
    }
}
