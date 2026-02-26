import XCTest
@testable import MacMonitor

final class FileRAMPolicyEventStoreTests: XCTestCase {
    func testRetentionKeepsOnlyRecentEvents() throws {
        let directoryURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = FileRAMPolicyEventStore(directoryURL: directoryURL, retentionDays: 7)

        let now = Date()
        let oldEvent = RAMPolicyEvent(
            timestamp: now.addingTimeInterval(-8 * 24 * 60 * 60),
            policyID: UUID(uuidString: "AAAAAAAA-1111-2222-3333-444444444444")!,
            bundleID: "com.test.cursor",
            displayName: "Cursor",
            observedBytes: 8,
            thresholdBytes: 4,
            triggerKind: .immediate,
            message: "old"
        )
        let newEvent = RAMPolicyEvent(
            timestamp: now,
            policyID: UUID(uuidString: "AAAAAAAA-1111-2222-3333-444444444444")!,
            bundleID: "com.test.cursor",
            displayName: "Cursor",
            observedBytes: 8,
            thresholdBytes: 4,
            triggerKind: .sustained,
            message: "new"
        )

        try store.append(oldEvent)
        try store.append(newEvent)
        store.pruneExpiredEvents(referenceDate: now)

        let events = store.recentEvents(limit: 10)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.message, "new")
        XCTAssertEqual(events.first?.triggerKind, .sustained)
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RAMPolicyEventStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
