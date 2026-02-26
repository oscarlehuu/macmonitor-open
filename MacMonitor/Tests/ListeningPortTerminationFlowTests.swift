import XCTest
@testable import MacMonitor

@MainActor
final class ListeningPortTerminationFlowTests: XCTestCase {
    func testDecliningForceKillSkipsOnlyRemainingSurvivors() async {
        let processCollector = FlowProcessCollector()
        let portCollector = FlowPortCollector()
        let terminator = FlowProcessTerminator()
        let sleeper = FlowNoopSleeper()

        let first = makePort(endpoint: "127.0.0.1:3000", port: 3000, pid: 1000)
        let duplicatePID = makePort(endpoint: "127.0.0.1:3001", port: 3001, pid: 1000)
        let second = makePort(endpoint: "127.0.0.1:5432", port: 5432, pid: 1001)
        portCollector.rows = [first, duplicatePID, second]

        terminator.summariesBySignal[.terminate] = ProcessTerminationSummary(
            results: [
                ProcessTerminationResult(pid: 1000, processName: "node", outcome: .terminated),
                ProcessTerminationResult(pid: 1001, processName: "postgres", outcome: .terminated)
            ]
        )
        terminator.aliveResponses = [[1000], [1000]]

        let viewModel = RAMDetailsViewModel(
            processCollector: processCollector,
            processTerminator: terminator,
            listeningPortCollector: portCollector,
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
        viewModel.skipForceKillRemainingPorts()
        await viewModel.pendingRefreshTask?.value

        XCTAssertEqual(
            viewModel.resultMessage,
            "Ports: 3 selected, 2 unique PID(s). Terminated 1, skipped 1, failed 0. Force declined: 1."
        )
    }

    private func makePort(endpoint: String, port: Int, pid: Int32) -> ListeningPort {
        ListeningPort(
            protocolName: "TCP",
            endpoint: endpoint,
            port: port,
            pid: pid,
            processName: port == 5432 ? "postgres" : "node",
            userID: 501,
            userName: "oscar",
            protectionReason: nil
        )
    }
}

private final class FlowProcessCollector: ProcessListCollecting, @unchecked Sendable {
    func collectTopProcesses(limit: Int, scope: ProcessScopeMode) throws -> [ProcessMemoryItem] {
        []
    }
}

private final class FlowPortCollector: ListeningPortCollecting, @unchecked Sendable {
    var rows: [ListeningPort] = []

    func collectListeningPorts() throws -> [ListeningPort] {
        rows
    }
}

private final class FlowProcessTerminator: ProcessTerminating {
    var summariesBySignal: [ProcessTerminationSignal: ProcessTerminationSummary] = [:]
    var aliveResponses: [Set<Int32>] = []

    func terminate(
        processes: [ProcessMemoryItem],
        selectedProcessIDs: Set<Int32>,
        signal: ProcessTerminationSignal
    ) -> ProcessTerminationSummary {
        summariesBySignal[signal] ?? ProcessTerminationSummary(results: [])
    }

    func aliveProcessIDs(in processIDs: Set<Int32>) -> Set<Int32> {
        if !aliveResponses.isEmpty {
            let next = aliveResponses.removeFirst()
            return processIDs.intersection(next)
        }
        return []
    }
}

@MainActor
private struct FlowNoopSleeper: TerminationPollSleeping {
    func sleep(seconds: TimeInterval) async {}
}
