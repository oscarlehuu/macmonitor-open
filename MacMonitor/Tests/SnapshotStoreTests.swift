import XCTest
@testable import MacMonitor

final class SnapshotStoreTests: XCTestCase {
    func testAppendAndLoadHistory() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapshotStoreTests-\(UUID().uuidString)", isDirectory: true)

        let store = SnapshotStore(baseDirectoryURL: tempDirectory, maxHistoryCount: 2)

        let first = makeSnapshot(minutesAgo: 10)
        let second = makeSnapshot(minutesAgo: 5)
        let third = makeSnapshot(minutesAgo: 1)

        store.append(first)
        store.append(second)
        store.append(third)

        let loaded = store.loadHistory()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.id, second.id)
        XCTAssertEqual(loaded.last?.id, third.id)
    }

    func testLegacyMigrationWritesJSONLBeforeRemovingLegacyFile() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapshotStoreMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tempDirectory.path)
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let legacyURL = tempDirectory.appendingPathComponent("snapshots.json")
        let jsonlURL = tempDirectory.appendingPathComponent("snapshots.jsonl")
        let legacySnapshot = makeSnapshot(minutesAgo: 1)
        let legacyPayload = try JSONEncoder().encode([legacySnapshot])
        try legacyPayload.write(to: legacyURL, options: .atomic)

        let fileManager = LegacyRemovalLockingFileManager()
        let store = SnapshotStore(fileManager: fileManager, baseDirectoryURL: tempDirectory, maxHistoryCount: 10)

        let loaded = store.loadHistory()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, legacySnapshot.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonlURL.path))
    }

    private func makeSnapshot(minutesAgo: Int) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date().addingTimeInterval(TimeInterval(-minutesAgo * 60)),
            memory: MemorySnapshot(usedBytes: 1, totalBytes: 2, pressure: .normal),
            storage: StorageSnapshot(usedBytes: 10, totalBytes: 20),
            thermal: ThermalSnapshot(state: .nominal),
            refreshReason: .interval
        )
    }
}

private final class LegacyRemovalLockingFileManager: FileManager {
    override func removeItem(at url: URL) throws {
        try super.removeItem(at: url)
        let directory = url.deletingLastPathComponent()
        try? super.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    }
}
