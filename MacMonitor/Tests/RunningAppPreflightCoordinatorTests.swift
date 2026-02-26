import XCTest
@testable import MacMonitor

@MainActor
final class RunningAppPreflightCoordinatorTests: XCTestCase {
    func testGracefulPreflightReturnsNotRunningWhenAppAlreadyClosed() async {
        let listing = FakeRunningAppListing()
        let coordinator = RunningAppPreflightCoordinator(
            listing: listing,
            sleeper: NoopRunningAppSleeper(),
            gracefulTimeoutSeconds: 0.01,
            pollIntervalSeconds: 0.01
        )

        let summary = await coordinator.gracefulQuitPreflight(for: [makeAppItem()])

        XCTAssertEqual(summary.results.count, 1)
        XCTAssertEqual(summary.results.first?.outcome, .notRunning)
    }

    func testGracefulPreflightMarksTerminatedWhenAppQuitsInTime() async {
        let app = FakeRunningApplication(
            processIdentifier: 100,
            bundleURL: URL(fileURLWithPath: "/Applications/Editor.app"),
            isTerminated: false,
            onTerminate: { $0.isTerminated = true }
        )
        let listing = FakeRunningAppListing()
        listing.bundleApplications["com.test.editor"] = [app]

        let coordinator = RunningAppPreflightCoordinator(
            listing: listing,
            sleeper: NoopRunningAppSleeper(),
            gracefulTimeoutSeconds: 0.01,
            pollIntervalSeconds: 0.01
        )

        let summary = await coordinator.gracefulQuitPreflight(for: [makeAppItem()])

        XCTAssertEqual(summary.results.first?.outcome, .terminatedGracefully)
        XCTAssertEqual(app.terminateCallCount, 1)
    }

    func testGracefulPreflightMarksStillRunningOnTimeout() async {
        let app = FakeRunningApplication(
            processIdentifier: 101,
            bundleURL: URL(fileURLWithPath: "/Applications/Editor.app"),
            isTerminated: false
        )
        let listing = FakeRunningAppListing()
        listing.bundleApplications["com.test.editor"] = [app]

        let coordinator = RunningAppPreflightCoordinator(
            listing: listing,
            sleeper: NoopRunningAppSleeper(),
            gracefulTimeoutSeconds: 0.01,
            pollIntervalSeconds: 0.01
        )

        let summary = await coordinator.gracefulQuitPreflight(for: [makeAppItem()])

        XCTAssertEqual(summary.results.first?.outcome, .stillRunning)
        XCTAssertEqual(app.terminateCallCount, 1)
    }

    func testForceQuitUsesBundlePathFallbackWhenBundleIdentifierMissing() async {
        let app = FakeRunningApplication(
            processIdentifier: 102,
            bundleURL: URL(fileURLWithPath: "/Applications/Editor.app"),
            isTerminated: false,
            onForceTerminate: { $0.isTerminated = true }
        )
        let listing = FakeRunningAppListing()
        listing.runningApps = [app]

        let coordinator = RunningAppPreflightCoordinator(
            listing: listing,
            sleeper: NoopRunningAppSleeper(),
            gracefulTimeoutSeconds: 0.01,
            pollIntervalSeconds: 0.01
        )

        let summary = await coordinator.forceQuit(for: [makeAppItem(bundleIdentifier: nil)])

        XCTAssertEqual(summary.results.first?.outcome, .forceTerminated)
        XCTAssertEqual(app.forceTerminateCallCount, 1)
    }

    private func makeAppItem(bundleIdentifier: String? = "com.test.editor") -> StorageManagedItem {
        StorageManagedItem(
            url: URL(fileURLWithPath: "/Applications/Editor.app"),
            displayName: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 120,
            protectionReason: nil,
            isDirectory: true,
            parentID: nil,
            bundleIdentifier: bundleIdentifier,
            appGroupID: nil
        )
    }
}

@MainActor
private final class FakeRunningAppListing: RunningApplicationListing {
    var bundleApplications: [String: [RunningApplication]] = [:]
    var runningApps: [RunningApplication] = []

    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplication] {
        bundleApplications[bundleIdentifier] ?? []
    }

    func allRunningApplications() -> [RunningApplication] {
        runningApps
    }
}

@MainActor
private final class FakeRunningApplication: RunningApplication {
    let processIdentifier: pid_t
    let bundleURL: URL?
    var isTerminated: Bool
    var terminateCallCount = 0
    var forceTerminateCallCount = 0
    let onTerminate: ((FakeRunningApplication) -> Void)?
    let onForceTerminate: ((FakeRunningApplication) -> Void)?

    init(
        processIdentifier: pid_t,
        bundleURL: URL?,
        isTerminated: Bool,
        onTerminate: ((FakeRunningApplication) -> Void)? = nil,
        onForceTerminate: ((FakeRunningApplication) -> Void)? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.bundleURL = bundleURL
        self.isTerminated = isTerminated
        self.onTerminate = onTerminate
        self.onForceTerminate = onForceTerminate
    }

    @discardableResult
    func terminate() -> Bool {
        terminateCallCount += 1
        onTerminate?(self)
        return true
    }

    @discardableResult
    func forceTerminate() -> Bool {
        forceTerminateCallCount += 1
        onForceTerminate?(self)
        return true
    }
}

@MainActor
private struct NoopRunningAppSleeper: RunningAppPollSleeping {
    func sleep(seconds: TimeInterval) async {}
}
