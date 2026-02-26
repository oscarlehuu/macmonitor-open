import XCTest
@testable import MacMonitor

@MainActor
final class StorageManagementViewModelTests: XCTestCase {
    func testPerformRefreshLoadsGroupedData() async {
        let manager = FakeStorageManager()
        let cursorBundleID = "com.todesktop.230313mzl4w4u92"
        let appID = "app:cursor"
        let appBundle = makeItem(
            path: "/Applications/Cursor.app",
            name: "Cursor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 400,
            protected: false,
            appGroupID: appID,
            bundleIdentifier: cursorBundleID
        )
        let appCache = makeItem(
            path: "/Users/test/Library/Caches/\(cursorBundleID)",
            name: "Cursor Cache",
            category: .cache,
            kind: .appCache,
            sizeBytes: 200,
            protected: false,
            appGroupID: appID,
            bundleIdentifier: cursorBundleID
        )
        let group = StorageAppGroup(
            id: appID,
            displayName: "Cursor",
            bundleIdentifier: cursorBundleID,
            items: [appBundle, appCache]
        )
        let loose = makeItem(
            path: "/tmp/Cache-A",
            name: "Cache-A",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 120,
            protected: false
        )
        manager.scanResult = makeScanResult(
            appGroups: [group],
            looseItems: [loose]
        )

        let viewModel = makeViewModel(manager: manager)

        await viewModel.performRefresh()

        XCTAssertEqual(viewModel.appGroups.count, 1)
        XCTAssertEqual(viewModel.appGroups.first?.displayName, "Cursor")
        XCTAssertEqual(viewModel.looseItems.count, 1)
        XCTAssertEqual(viewModel.looseItems.first?.displayName, "Cache-A")
        XCTAssertEqual(manager.scanCallCount, 1)
    }

    func testToggleSelectionSkipsProtectedItems() async {
        let manager = FakeStorageManager()
        let protected = makeItem(
            path: "/System/Library",
            name: "Library",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 1,
            protected: true
        )
        let allowed = makeItem(
            path: "/tmp/Allowed",
            name: "Allowed",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 2,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [protected, allowed])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()

        viewModel.toggleSelection(for: protected.id)
        viewModel.toggleSelection(for: allowed.id)

        XCTAssertEqual(viewModel.selectedItemIDs, [allowed.id])
    }

    func testDeleteSelectedSendsOnlyAllowedIDs() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let protected = makeItem(
            path: "/System/Library",
            name: "Library",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 1,
            protected: true
        )
        let allowed = makeItem(
            path: "/tmp/Allowed",
            name: "Allowed",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 2,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [protected, allowed])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: allowed.id, displayName: allowed.displayName, outcome: .deleted)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [protected.id, allowed.id]

        await viewModel.deleteSelected()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [allowed.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 1, skipped 0, failed 0.")
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
    }

    func testProjectionUsesDiskUsageAndSelection() async {
        let manager = FakeStorageManager()
        let selected = makeItem(
            path: "/tmp/FutureDelete",
            name: "FutureDelete",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 200,
            protected: false
        )
        manager.scanResult = makeScanResult(
            looseItems: [selected],
            diskUsage: StorageDiskUsage(usedBytes: 800, totalBytes: 1_000)
        )

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.toggleSelection(for: selected.id)

        XCTAssertEqual(viewModel.currentUsedBytes, 800)
        XCTAssertEqual(viewModel.currentTotalBytes, 1_000)
        XCTAssertEqual(viewModel.willDeleteBytes, 200)
        XCTAssertEqual(viewModel.projectedUsedBytes, 600)
        XCTAssertEqual(viewModel.projectedUsageRatio, 0.6, accuracy: 0.0001)
    }

    func testApplyPresetSelectsNodeTargetsOnly() async {
        let manager = FakeStorageManager()
        let nodeModules = makeItem(
            path: "/Users/test/Developer/demo/node_modules",
            name: "node_modules",
            category: .folder,
            kind: .nodeModules,
            sizeBytes: 300,
            protected: false
        )
        let npmProtected = makeItem(
            path: "/Users/test/.npm",
            name: ".npm",
            category: .cache,
            kind: .npmCache,
            sizeBytes: 250,
            protected: true
        )
        let xcode = makeItem(
            path: "/Users/test/Library/Developer/Xcode/DerivedData",
            name: "DerivedData",
            category: .cache,
            kind: .derivedData,
            sizeBytes: 500,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [nodeModules, npmProtected, xcode])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.applyPreset(.node)

        XCTAssertEqual(viewModel.activePreset, .node)
        XCTAssertEqual(viewModel.selectedItemIDs, [nodeModules.id])
    }

    func testSummaryDiskUsageFallbackIsUsedWhenScanDiskUsageMissing() async {
        let manager = FakeStorageManager()
        manager.scanResult = makeScanResult(looseItems: [])

        let viewModel = makeViewModel(manager: manager)
        viewModel.updateDiskUsageSnapshot(StorageDiskUsage(usedBytes: 900, totalBytes: 1_500))
        await viewModel.performRefresh()

        XCTAssertEqual(viewModel.currentUsedBytes, 900)
        XCTAssertEqual(viewModel.currentTotalBytes, 1_500)
    }

    func testDeleteSelectedShowsForcePromptWhenAppStillRunning() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let app = makeItem(
            path: "/Applications/Editor.app",
            name: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 200,
            protected: false,
            bundleIdentifier: "com.test.editor"
        )
        let cache = makeItem(
            path: "/tmp/EditorCache",
            name: "EditorCache",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 20,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [app, cache])
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id, cache.id]

        await viewModel.deleteSelected()

        XCTAssertTrue(viewModel.showingForceQuitConfirmation)
        XCTAssertEqual(viewModel.forceQuitCandidateNames, [app.displayName])
        XCTAssertEqual(manager.lastDeletedIDs, [])
    }

    func testSkipForceQuitDeletesOtherItemsAndReportsDeclined() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let app = makeItem(
            path: "/Applications/Editor.app",
            name: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 200,
            protected: false,
            bundleIdentifier: "com.test.editor"
        )
        let cache = makeItem(
            path: "/tmp/EditorCache",
            name: "EditorCache",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 20,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [app, cache])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: cache.id, displayName: cache.displayName, outcome: .deleted)
            ]
        )
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id, cache.id]

        await viewModel.deleteSelected()
        await viewModel.skipForceQuitAndDelete()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [cache.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 1, skipped 1, failed 0. Force declined: 1.")
    }

    func testConfirmForceQuitDeletesRecoveredApps() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let app = makeItem(
            path: "/Applications/Editor.app",
            name: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 200,
            protected: false,
            bundleIdentifier: "com.test.editor"
        )
        let cache = makeItem(
            path: "/tmp/EditorCache",
            name: "EditorCache",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 20,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [app, cache])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: app.id, displayName: app.displayName, outcome: .deleted),
                StorageDeletionResult(id: cache.id, displayName: cache.displayName, outcome: .deleted)
            ]
        )
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )
        coordinator.forceSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .forceTerminated)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id, cache.id]

        await viewModel.deleteSelected()
        await viewModel.confirmForceQuitAndDelete()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [app.id, cache.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 2, skipped 0, failed 0.")
    }

    func testConfirmForceQuitSkipsAppsStillRunningAfterForce() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let app = makeItem(
            path: "/Applications/Editor.app",
            name: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 200,
            protected: false,
            bundleIdentifier: "com.test.editor"
        )
        let cache = makeItem(
            path: "/tmp/EditorCache",
            name: "EditorCache",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 20,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [app, cache])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: cache.id, displayName: cache.displayName, outcome: .deleted)
            ]
        )
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )
        coordinator.forceSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id, cache.id]

        await viewModel.deleteSelected()
        await viewModel.confirmForceQuitAndDelete()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [cache.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 1, skipped 1, failed 0. Still running: 1.")
    }

    func testGrantInitialAccessPersistsPromptStateAcrossRestart() {
        let manager = FakeStorageManager()
        let suiteName = "StorageManagementViewModelTests.InitialAccess.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacMonitor-InitialAccess-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let firstViewModel = StorageManagementViewModel(storageManager: manager, userDefaults: defaults)
        XCTAssertTrue(firstViewModel.shouldRequestInitialAccess())

        firstViewModel.grantInitialAccess(to: tempRoot)
        XCTAssertFalse(firstViewModel.shouldRequestInitialAccess())

        let secondViewModel = StorageManagementViewModel(storageManager: manager, userDefaults: defaults)
        XCTAssertFalse(secondViewModel.shouldRequestInitialAccess())
    }

    func testShouldRequestInitialAccessReadsLatestPersistedFlag() {
        let manager = FakeStorageManager()
        let suiteName = "StorageManagementViewModelTests.InitialAccessFlag.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = StorageManagementViewModel(storageManager: manager, userDefaults: defaults)
        XCTAssertTrue(viewModel.shouldRequestInitialAccess())

        defaults.set(true, forKey: "storage.initialAccessPromptShown")
        defaults.synchronize()

        XCTAssertFalse(viewModel.shouldRequestInitialAccess())
    }

    private func makeViewModel(
        manager: FakeStorageManager,
        preflightCoordinator: FakeRunningAppPreflightCoordinator = FakeRunningAppPreflightCoordinator()
    ) -> StorageManagementViewModel {
        let suiteName = "StorageManagementViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return StorageManagementViewModel(
            storageManager: manager,
            runningAppPreflightCoordinator: preflightCoordinator,
            userDefaults: defaults
        )
    }

    private func makeItem(
        path: String,
        name: String,
        category: StorageManagedItemCategory,
        kind: StorageManagedItemKind,
        sizeBytes: UInt64,
        protected: Bool,
        appGroupID: String? = nil,
        bundleIdentifier: String? = nil,
        parentID: String? = nil,
        isDirectory: Bool = true
    ) -> StorageManagedItem {
        StorageManagedItem(
            url: URL(fileURLWithPath: path),
            displayName: name,
            category: category,
            kind: kind,
            sizeBytes: sizeBytes,
            protectionReason: protected ? .systemPath : nil,
            isDirectory: isDirectory,
            parentID: parentID,
            bundleIdentifier: bundleIdentifier,
            appGroupID: appGroupID
        )
    }

    private func makeScanResult(
        appGroups: [StorageAppGroup] = [],
        looseItems: [StorageManagedItem] = [],
        diskUsage: StorageDiskUsage? = nil
    ) -> StorageScanResult {
        StorageScanResult(diskUsage: diskUsage, appGroups: appGroups, looseItems: looseItems)
    }
}

private final class FakeStorageManager: StorageManaging, @unchecked Sendable {
    private let lock = NSLock()

    var scanResult = StorageScanResult(diskUsage: nil, appGroups: [], looseItems: [])
    var drilledItemsByParentID: [String: [StorageManagedItem]] = [:]
    var deleteSummary = StorageDeletionSummary(results: [])
    private(set) var scanCallCount = 0
    private(set) var lastDeletedIDs: Set<String> = []

    func scan(customFolders: [URL]) -> StorageScanResult {
        lock.lock()
        defer { lock.unlock() }
        scanCallCount += 1
        return scanResult
    }

    func drillDown(item: StorageManagedItem, limit: Int) -> [StorageManagedItem] {
        lock.lock()
        defer { lock.unlock() }
        let children = drilledItemsByParentID[item.id] ?? []
        return Array(children.prefix(max(limit, 0)))
    }

    func delete(items: [StorageManagedItem], selectedItemIDs: Set<String>) -> StorageDeletionSummary {
        lock.lock()
        defer { lock.unlock() }
        lastDeletedIDs = selectedItemIDs
        return deleteSummary
    }
}

@MainActor
private final class FakeRunningAppPreflightCoordinator: RunningAppPreflightCoordinating {
    var gracefulSummary = RunningAppPreflightSummary(results: [])
    var forceSummary = RunningAppPreflightSummary(results: [])

    func gracefulQuitPreflight(for items: [StorageManagedItem]) async -> RunningAppPreflightSummary {
        if !gracefulSummary.results.isEmpty {
            return gracefulSummary
        }
        return RunningAppPreflightSummary(
            results: items.map { item in
                RunningAppPreflightResult(itemID: item.id, displayName: item.displayName, outcome: .notRunning)
            }
        )
    }

    func forceQuit(for items: [StorageManagedItem]) async -> RunningAppPreflightSummary {
        if !forceSummary.results.isEmpty {
            return forceSummary
        }
        return RunningAppPreflightSummary(
            results: items.map { item in
                RunningAppPreflightResult(itemID: item.id, displayName: item.displayName, outcome: .forceTerminated)
            }
        )
    }
}
