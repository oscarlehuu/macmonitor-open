import XCTest
@testable import MacMonitor

@MainActor
final class RAMDetailsViewModelTests: XCTestCase {
    func testStartLoadsProcesses() async {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        collector.mineItems = [makeProcess(pid: 100, name: "Safari", userID: 501, protected: false)]
        collector.allItems = collector.mineItems

        await viewModel.performRefresh()

        XCTAssertEqual(viewModel.processes.count, 1)
        XCTAssertEqual(collector.callCount, 2)
    }

    func testChangingScopeClearsSelectionAndRefreshes() async {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        collector.mineItems = [makeProcess(pid: 101, name: "Xcode", userID: 501, protected: false)]
        collector.allItems = [
            makeProcess(pid: 101, name: "Xcode", userID: 501, protected: false),
            makeProcess(pid: 55, name: "launchd", userID: 0, protected: true)
        ]

        await viewModel.performRefresh()
        viewModel.selectedProcessIDs = [101]

        viewModel.setScopeMode(.allDiscoverable)
        await viewModel.pendingRefreshTask?.value

        XCTAssertTrue(viewModel.selectedProcessIDs.isEmpty)
        XCTAssertEqual(viewModel.scopeMode, .allDiscoverable)
        XCTAssertEqual(collector.callCount, 4)
        viewModel.stop()
    }

    func testTerminateSelectedUsesAllowedProcessesOnly() async {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        terminator.summary = ProcessTerminationSummary(
            results: [
                ProcessTerminationResult(pid: 200, processName: "Allowed", outcome: .terminated)
            ]
        )

        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        collector.mineItems = [
            makeProcess(pid: 200, name: "Allowed", userID: 501, protected: false),
            makeProcess(pid: 201, name: "Protected", userID: 501, protected: true)
        ]
        collector.allItems = collector.mineItems

        await viewModel.performRefresh()
        viewModel.selectedProcessIDs = [200, 201]

        await viewModel.terminateSelected()

        XCTAssertEqual(terminator.lastSelectedProcessIDs, [200])
        XCTAssertTrue(viewModel.selectedProcessIDs.isEmpty)
        XCTAssertEqual(viewModel.resultMessage, "Terminated 1, skipped 0, failed 0.")
    }

    func testRequestTerminateSelectedIgnoresProtectedOnlySelection() async {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        collector.mineItems = [makeProcess(pid: 300, name: "Protected", userID: 501, protected: true)]
        collector.allItems = collector.mineItems

        await viewModel.performRefresh()
        viewModel.selectedProcessIDs = [300]

        viewModel.requestTerminateSelected()

        XCTAssertFalse(viewModel.showingTerminateConfirmation)
    }

    func testComputesMineAndAllProcessBytesFromAllScopeData() async {
        let collector = FakeProcessCollector()
        collector.mineItems = [makeProcess(pid: 401, name: "Mine", userID: 501, protected: false, rankingBytes: 120)]
        collector.allItems = [
            makeProcess(pid: 401, name: "Mine", userID: 501, protected: false, rankingBytes: 120),
            makeProcess(pid: 402, name: "Root", userID: 0, protected: true, rankingBytes: 300)
        ]
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        await viewModel.performRefresh()

        XCTAssertEqual(viewModel.myProcessBytes, 120)
        XCTAssertEqual(viewModel.allProcessBytes, 420)
    }

    func testSetShowAllMineLoadsAllMineRows() async {
        let collector = FakeProcessCollector()
        collector.mineItems = [
            makeProcess(pid: 501, name: "A", userID: 501, protected: false, rankingBytes: 300),
            makeProcess(pid: 502, name: "B", userID: 501, protected: false, rankingBytes: 200),
            makeProcess(pid: 503, name: "C", userID: 501, protected: false, rankingBytes: 100)
        ]
        collector.allItems = collector.mineItems
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 2,
            refreshInterval: 3600,
            currentUserID: 501
        )

        await viewModel.performRefresh()
        XCTAssertEqual(viewModel.processes.count, 2)
        XCTAssertFalse(viewModel.showAllMine)

        viewModel.setShowAllMine(true)
        await viewModel.pendingRefreshTask?.value

        XCTAssertTrue(viewModel.showAllMine)
        XCTAssertEqual(viewModel.processes.count, 3)
        XCTAssertEqual(collector.callCount, 4)
    }

    func testSetModeToPortsLoadsListeningRows() async {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let portsCollector = FakeListeningPortCollector()
        portsCollector.rows = [
            makePort(
                endpoint: "127.0.0.1:3000",
                port: 3000,
                pid: 600,
                processName: "node",
                userID: 501,
                protected: false
            )
        ]
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            listeningPortCollector: portsCollector,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        viewModel.setMode(.ports)
        await viewModel.pendingRefreshTask?.value

        XCTAssertEqual(viewModel.mode, .ports)
        XCTAssertEqual(viewModel.listeningPorts.count, 1)
        XCTAssertEqual(viewModel.listeningPorts.first?.port, 3000)
    }

    func testTerminateSelectedPortsDeduplicatesPIDsAndShowsForcePrompt() async {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let portsCollector = FakeListeningPortCollector()
        let sleeper = FakePollSleeper()
        let first = makePort(
            endpoint: "127.0.0.1:3000",
            port: 3000,
            pid: 700,
            processName: "node",
            userID: 501,
            protected: false
        )
        let duplicatePID = makePort(
            endpoint: "127.0.0.1:3001",
            port: 3001,
            pid: 700,
            processName: "node",
            userID: 501,
            protected: false
        )
        let second = makePort(
            endpoint: "127.0.0.1:5432",
            port: 5432,
            pid: 701,
            processName: "postgres",
            userID: 501,
            protected: false
        )
        portsCollector.rows = [first, duplicatePID, second]
        terminator.summariesBySignal[.terminate] = ProcessTerminationSummary(
            results: [
                ProcessTerminationResult(pid: 700, processName: "node", outcome: .terminated),
                ProcessTerminationResult(pid: 701, processName: "postgres", outcome: .terminated)
            ]
        )
        terminator.aliveResponses = [[700], [700]]

        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            listeningPortCollector: portsCollector,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501,
            gracefulTimeoutSeconds: 0.01,
            pollIntervalSeconds: 0.01,
            pollSleeper: sleeper
        )

        viewModel.setMode(.ports)
        await viewModel.pendingRefreshTask?.value
        viewModel.selectedPortIDs = [first.id, duplicatePID.id, second.id]

        await viewModel.terminateSelected()

        XCTAssertEqual(terminator.lastSelectedProcessIDs, [700, 701])
        XCTAssertEqual(terminator.lastSignals, [.terminate])
        XCTAssertTrue(viewModel.showingForceKillConfirmation)
        XCTAssertEqual(viewModel.pendingForceKillPIDCount, 1)
    }

    func testSkipForceKillRemainingPortsReportsDeclined() async {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let portsCollector = FakeListeningPortCollector()
        let sleeper = FakePollSleeper()
        let first = makePort(
            endpoint: "127.0.0.1:3000",
            port: 3000,
            pid: 800,
            processName: "node",
            userID: 501,
            protected: false
        )
        let second = makePort(
            endpoint: "127.0.0.1:5432",
            port: 5432,
            pid: 801,
            processName: "postgres",
            userID: 501,
            protected: false
        )
        portsCollector.rows = [first, second]
        terminator.summariesBySignal[.terminate] = ProcessTerminationSummary(
            results: [
                ProcessTerminationResult(pid: 800, processName: "node", outcome: .terminated),
                ProcessTerminationResult(pid: 801, processName: "postgres", outcome: .terminated)
            ]
        )
        terminator.aliveResponses = [[800], [800]]

        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            listeningPortCollector: portsCollector,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501,
            gracefulTimeoutSeconds: 0.01,
            pollIntervalSeconds: 0.01,
            pollSleeper: sleeper
        )

        viewModel.setMode(.ports)
        await viewModel.pendingRefreshTask?.value
        viewModel.selectedPortIDs = [first.id, second.id]

        await viewModel.terminateSelected()
        viewModel.skipForceKillRemainingPorts()
        await viewModel.pendingRefreshTask?.value

        XCTAssertEqual(viewModel.resultMessage, "Ports: 2 selected, 2 unique PID(s). Terminated 1, skipped 1, failed 0. Force declined: 1.")
        XCTAssertTrue(viewModel.selectedPortIDs.isEmpty)
    }

    func testConfirmForceKillRemainingPortsUsesKillSignalForSurvivors() async {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let portsCollector = FakeListeningPortCollector()
        let sleeper = FakePollSleeper()
        let first = makePort(
            endpoint: "127.0.0.1:3000",
            port: 3000,
            pid: 900,
            processName: "node",
            userID: 501,
            protected: false
        )
        let second = makePort(
            endpoint: "127.0.0.1:5432",
            port: 5432,
            pid: 901,
            processName: "postgres",
            userID: 501,
            protected: false
        )
        portsCollector.rows = [first, second]
        terminator.summariesBySignal[.terminate] = ProcessTerminationSummary(
            results: [
                ProcessTerminationResult(pid: 900, processName: "node", outcome: .terminated),
                ProcessTerminationResult(pid: 901, processName: "postgres", outcome: .terminated)
            ]
        )
        terminator.summariesBySignal[.kill] = ProcessTerminationSummary(
            results: [
                ProcessTerminationResult(pid: 900, processName: "node", outcome: .terminated)
            ]
        )
        terminator.aliveResponses = [[900], [900], [900], []]

        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            listeningPortCollector: portsCollector,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501,
            gracefulTimeoutSeconds: 0.01,
            pollIntervalSeconds: 0.01,
            pollSleeper: sleeper
        )

        viewModel.setMode(.ports)
        await viewModel.pendingRefreshTask?.value
        viewModel.selectedPortIDs = [first.id, second.id]

        await viewModel.terminateSelected()
        await viewModel.confirmForceKillRemainingPorts()
        await viewModel.pendingRefreshTask?.value

        XCTAssertEqual(terminator.lastSignals, [.terminate, .kill])
        XCTAssertEqual(viewModel.resultMessage, "Ports: 2 selected, 2 unique PID(s). Terminated 2, skipped 0, failed 0.")
    }

    private func makePort(
        endpoint: String,
        port: Int,
        pid: Int32,
        processName: String,
        userID: uid_t,
        protected: Bool
    ) -> ListeningPort {
        ListeningPort(
            protocolName: "TCP",
            endpoint: endpoint,
            port: port,
            pid: pid,
            processName: processName,
            userID: userID,
            userName: "oscar",
            protectionReason: protected ? .systemProcess : nil
        )
    }

    private func makeProcess(pid: Int32, name: String, userID: uid_t, protected: Bool, rankingBytes: UInt64 = 120) -> ProcessMemoryItem {
        ProcessMemoryItem(
            pid: pid,
            name: name,
            userID: userID,
            userName: "oscar",
            residentBytes: rankingBytes,
            footprintBytes: rankingBytes,
            bsdFlags: 0,
            protectionReason: protected ? .systemProcess : nil
        )
    }
}

private final class FakeProcessCollector: ProcessListCollecting, @unchecked Sendable {
    var mineItems: [ProcessMemoryItem] = []
    var allItems: [ProcessMemoryItem] = []
    var error: Error?
    private(set) var callCount = 0

    func collectTopProcesses(limit: Int, scope: ProcessScopeMode) throws -> [ProcessMemoryItem] {
        callCount += 1
        if let error {
            throw error
        }
        switch scope {
        case .sameUserOnly:
            return Array(mineItems.prefix(limit))
        case .allDiscoverable:
            return Array(allItems.prefix(limit))
        }
    }
}

private final class FakeProcessTerminator: ProcessTerminating {
    var summary = ProcessTerminationSummary(results: [])
    var summariesBySignal: [ProcessTerminationSignal: ProcessTerminationSummary] = [:]
    var aliveProcessIDsResult: Set<Int32> = []
    var aliveResponses: [Set<Int32>] = []
    private(set) var lastSelectedProcessIDs: Set<Int32> = []
    private(set) var lastSignals: [ProcessTerminationSignal] = []

    func terminate(
        processes: [ProcessMemoryItem],
        selectedProcessIDs: Set<Int32>,
        signal: ProcessTerminationSignal
    ) -> ProcessTerminationSummary {
        lastSelectedProcessIDs = selectedProcessIDs
        lastSignals.append(signal)
        return summariesBySignal[signal] ?? summary
    }

    func aliveProcessIDs(in processIDs: Set<Int32>) -> Set<Int32> {
        if !aliveResponses.isEmpty {
            let next = aliveResponses.removeFirst()
            return processIDs.intersection(next)
        }
        return processIDs.intersection(aliveProcessIDsResult)
    }
}

private final class FakeListeningPortCollector: ListeningPortCollecting, @unchecked Sendable {
    var rows: [ListeningPort] = []

    func collectListeningPorts() throws -> [ListeningPort] {
        rows
    }
}

@MainActor
private struct FakePollSleeper: TerminationPollSleeping {
    func sleep(seconds: TimeInterval) async {}
}
