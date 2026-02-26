import XCTest
@testable import MacMonitor

final class FileRAMPolicyStoreTests: XCTestCase {
    func testSaveLoadUpdateDeletePolicy() throws {
        let directoryURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = FileRAMPolicyStore(directoryURL: directoryURL)

        var policy = RAMPolicy(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            bundleID: "com.test.cursor",
            displayName: "Cursor",
            limitMode: .percent,
            limitValue: 10,
            triggerMode: .both,
            sustainedSeconds: 15,
            notifyCooldownSeconds: 300,
            enabled: true,
            updatedAt: Date(timeIntervalSince1970: 1)
        )

        try store.savePolicy(policy)

        var loaded = store.loadPolicies()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.bundleID, "com.test.cursor")
        XCTAssertEqual(loaded.first?.limitValue, 10)

        policy.limitMode = .gigabytes
        policy.limitValue = 6
        policy.updatedAt = Date(timeIntervalSince1970: 2)
        try store.savePolicy(policy)

        loaded = store.loadPolicies()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.limitMode, .gigabytes)
        XCTAssertEqual(loaded.first?.limitValue, 6)

        try store.deletePolicy(id: policy.id)
        loaded = store.loadPolicies()
        XCTAssertTrue(loaded.isEmpty)
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RAMPolicyStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
