import XCTest
@testable import MacMonitor

final class MenuBarDisplayFormatterTests: XCTestCase {
    func testIconModeReturnsNil() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 4, memoryTotal: 8, storageUsed: 40, storageTotal: 100),
            mode: .icon,
            memoryFormat: .percentUsage,
            storageFormat: .numberLeft
        )

        XCTAssertNil(title)
    }

    func testMemoryPercentUsageTitle() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 3, memoryTotal: 4, storageUsed: 0, storageTotal: 1),
            mode: .memory,
            memoryFormat: .percentUsage,
            storageFormat: .percentUsage
        )

        XCTAssertEqual(title, "RAM: 75%")
    }

    func testStorageNumberLeftTitle() {
        let snapshot = makeSnapshot(
            memoryUsed: 0,
            memoryTotal: 1,
            storageUsed: 80,
            storageTotal: 100
        )

        let title = MenuBarDisplayFormatter.valueText(
            for: snapshot,
            mode: .storage,
            memoryFormat: .percentUsage,
            storageFormat: .numberLeft
        )

        XCTAssertEqual(title, "SSD: \(MetricFormatter.bytes(20)) left")
    }

    func testBothMetricsTitle() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 3, memoryTotal: 4, storageUsed: 80, storageTotal: 100),
            mode: .both,
            memoryFormat: .percentUsage,
            storageFormat: .percentUsage
        )

        XCTAssertEqual(title, "RAM: 75% | SSD: 80%")
    }

    func testPlaceholderWhenSnapshotMissing() {
        let title = MenuBarDisplayFormatter.valueText(
            for: nil,
            mode: .memory,
            memoryFormat: .numberUsage,
            storageFormat: .percentUsage
        )

        XCTAssertEqual(title, "RAM: --")
    }

    func testMemoryNumberUsageTitleDoesNotUsePercentSymbol() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(
                memoryUsed: 1_073_741_824,
                memoryTotal: 2_147_483_648,
                storageUsed: 0,
                storageTotal: 1
            ),
            mode: .memory,
            memoryFormat: .numberUsage,
            storageFormat: .percentUsage
        )

        XCTAssertNotNil(title)
        XCTAssertFalse(title?.contains("%") ?? true)
    }

    private func makeSnapshot(
        memoryUsed: UInt64,
        memoryTotal: UInt64,
        storageUsed: UInt64,
        storageTotal: UInt64
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(),
            memory: MemorySnapshot(
                usedBytes: memoryUsed,
                totalBytes: memoryTotal,
                pressure: .normal
            ),
            storage: StorageSnapshot(
                usedBytes: storageUsed,
                totalBytes: storageTotal
            ),
            thermal: ThermalSnapshot(state: .nominal),
            refreshReason: .manual
        )
    }
}
