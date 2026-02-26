import Combine
import Foundation

@MainActor
protocol TerminationPollSleeping {
    func sleep(seconds: TimeInterval) async
}

@MainActor
private struct TaskTerminationPollSleeper: TerminationPollSleeping {
    func sleep(seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

private struct EmptyListeningPortCollector: ListeningPortCollecting {
    func collectListeningPorts() throws -> [ListeningPort] {
        []
    }
}

@MainActor
final class RAMDetailsViewModel: ObservableObject {
    private struct PendingPortsTerminationContext {
        let selectedPortCount: Int
        let processLookup: [Int32: ProcessMemoryItem]
        let gracefulSummary: ProcessTerminationSummary
        let survivors: Set<Int32>
    }

    @Published private(set) var mode: RAMDetailsMode = .processes
    @Published private(set) var processes: [ProcessMemoryItem] = []
    @Published private(set) var listeningPorts: [ListeningPort] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isTerminating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var resultMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var scopeMode: ProcessScopeMode = .sameUserOnly
    @Published private(set) var showAllMine = false
    @Published private(set) var myProcessBytes: UInt64 = 0
    @Published private(set) var allProcessBytes: UInt64 = 0
    @Published private(set) var myProcessCount: Int = 0
    @Published private(set) var allProcessCount: Int = 0
    @Published private(set) var pendingForceKillPIDCount: Int = 0
    @Published var selectedProcessIDs: Set<Int32> = []
    @Published var selectedPortIDs: Set<String> = []
    @Published var showingTerminateConfirmation = false
    @Published var showingForceKillConfirmation = false

    private let processCollector: ProcessListCollecting
    private let listeningPortCollector: ListeningPortCollecting
    private let processTerminator: ProcessTerminating
    private let maxRows: Int
    private let refreshInterval: TimeInterval
    private let currentUserID: uid_t
    private let gracefulTimeoutSeconds: TimeInterval
    private let pollIntervalSeconds: TimeInterval
    private let pollSleeper: TerminationPollSleeping

    private var refreshCancellable: AnyCancellable?
    private var hasStarted = false
    private var pendingPortsTerminationContext: PendingPortsTerminationContext?
    private(set) var pendingRefreshTask: Task<Void, Never>?

    init(
        processCollector: ProcessListCollecting,
        processTerminator: ProcessTerminating,
        listeningPortCollector: ListeningPortCollecting = EmptyListeningPortCollector(),
        maxRows: Int = 20,
        refreshInterval: TimeInterval = 5,
        currentUserID: uid_t = getuid(),
        gracefulTimeoutSeconds: TimeInterval = 10,
        pollIntervalSeconds: TimeInterval = 0.25,
        pollSleeper: TerminationPollSleeping = TaskTerminationPollSleeper()
    ) {
        self.processCollector = processCollector
        self.processTerminator = processTerminator
        self.listeningPortCollector = listeningPortCollector
        self.maxRows = maxRows
        self.refreshInterval = refreshInterval
        self.currentUserID = currentUserID
        self.gracefulTimeoutSeconds = gracefulTimeoutSeconds
        self.pollIntervalSeconds = pollIntervalSeconds
        self.pollSleeper = pollSleeper
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        refresh()

        refreshCancellable = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func stop() {
        guard hasStarted else { return }
        hasStarted = false
        refreshCancellable?.cancel()
        refreshCancellable = nil
        pendingRefreshTask?.cancel()
        pendingRefreshTask = nil
        resetPendingPortsTermination()
    }

    func setMode(_ mode: RAMDetailsMode) {
        guard mode != self.mode else { return }
        self.mode = mode
        selectedProcessIDs.removeAll()
        selectedPortIDs.removeAll()
        showingTerminateConfirmation = false
        showingForceKillConfirmation = false
        resetPendingPortsTermination()
        refresh()
    }

    func setScopeMode(_ scope: ProcessScopeMode) {
        guard mode == .processes else { return }
        guard scope != scopeMode else { return }
        scopeMode = scope
        if scope != .sameUserOnly {
            showAllMine = false
        }
        selectedProcessIDs.removeAll()
        refresh()
    }

    func setShowAllMine(_ enabled: Bool) {
        guard mode == .processes else { return }
        guard enabled != showAllMine else { return }
        showAllMine = enabled
        selectedProcessIDs.removeAll()
        refresh()
    }

    func refresh() {
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { await performRefresh() }
    }

    func performRefresh() async {
        switch mode {
        case .processes:
            await performProcessRefresh()
        case .ports:
            await performPortsRefresh()
        }
    }

    func toggleSelection(for processID: Int32) {
        guard mode == .processes else { return }
        guard let process = processes.first(where: { $0.pid == processID }), !process.isProtected else { return }

        if selectedProcessIDs.contains(processID) {
            selectedProcessIDs.remove(processID)
        } else {
            selectedProcessIDs.insert(processID)
        }
    }

    func togglePortSelection(for portID: String) {
        guard mode == .ports else { return }
        guard let row = listeningPorts.first(where: { $0.id == portID }), !row.isProtected else { return }

        if selectedPortIDs.contains(portID) {
            selectedPortIDs.remove(portID)
        } else {
            selectedPortIDs.insert(portID)
        }
    }

    func requestTerminateSelected() {
        guard !isTerminating else { return }
        guard selectedAllowedCount > 0 else { return }
        showingTerminateConfirmation = true
    }

    func terminateSelected() async {
        switch mode {
        case .processes:
            await terminateSelectedProcesses()
        case .ports:
            await terminateSelectedPorts()
        }
    }

    func confirmForceKillRemainingPorts() async {
        guard let context = pendingPortsTerminationContext else {
            showingForceKillConfirmation = false
            return
        }

        showingForceKillConfirmation = false
        isTerminating = true
        await Task.yield()

        let survivorsNow = processTerminator.aliveProcessIDs(in: context.survivors)
        if survivorsNow.isEmpty {
            finalizePortsTermination(
                selectedPortCount: context.selectedPortCount,
                processLookup: context.processLookup,
                gracefulSummary: context.gracefulSummary,
                survivorsAfterDecision: [],
                forceSummary: nil,
                forceDeclined: false
            )
            return
        }

        let forceSummary = processTerminator.terminate(
            processes: Array(context.processLookup.values),
            selectedProcessIDs: survivorsNow,
            signal: .kill
        )
        let survivorsAfterForce = await waitForAlivePIDs(in: survivorsNow)
        guard !Task.isCancelled else { return }

        finalizePortsTermination(
            selectedPortCount: context.selectedPortCount,
            processLookup: context.processLookup,
            gracefulSummary: context.gracefulSummary,
            survivorsAfterDecision: survivorsAfterForce,
            forceSummary: forceSummary,
            forceDeclined: false
        )
    }

    func skipForceKillRemainingPorts() {
        guard let context = pendingPortsTerminationContext else {
            showingForceKillConfirmation = false
            return
        }

        showingForceKillConfirmation = false
        finalizePortsTermination(
            selectedPortCount: context.selectedPortCount,
            processLookup: context.processLookup,
            gracefulSummary: context.gracefulSummary,
            survivorsAfterDecision: context.survivors,
            forceSummary: nil,
            forceDeclined: true
        )
    }

    func cancelForceKillPrompt() {
        showingForceKillConfirmation = false
        isTerminating = false
        resetPendingPortsTermination()
    }

    var selectedAllowedCount: Int {
        switch mode {
        case .processes:
            return selectedAllowedProcesses.count
        case .ports:
            return selectedAllowedPorts.count
        }
    }

    var selectedAllowedBytes: UInt64 {
        switch mode {
        case .processes:
            return selectedAllowedProcesses.reduce(0) { $0 + $1.rankingBytes }
        case .ports:
            return 0
        }
    }

    var selectedAllowedPIDCount: Int {
        Set(selectedAllowedPorts.map(\.pid)).count
    }

    var canTerminateSelection: Bool {
        selectedAllowedCount > 0 && !isTerminating
    }

    var listedRowsBytes: UInt64 {
        processes.reduce(0) { $0 + $1.rankingBytes }
    }

    var defaultTopRows: Int {
        maxRows
    }

    var canToggleAllMine: Bool {
        scopeMode == .sameUserOnly && myProcessCount > maxRows
    }

    var areDisplayedRowsCurrentUserOnly: Bool {
        !processes.isEmpty && processes.allSatisfy { $0.userID == currentUserID }
    }

    var hasMoreAllRowsThanDisplayed: Bool {
        allProcessCount > processes.count
    }

    var terminationInfoTooltip: String {
        switch mode {
        case .processes:
            return "This action proceeds with allowed processes only."
        case .ports:
            return "Selected ports are deduplicated to unique PIDs before termination."
        }
    }

    var forceKillPromptMessage: String {
        if pendingForceKillPIDCount == 1 {
            return "1 process is still running after graceful termination. Force kill may lose unsaved work."
        }
        return "\(pendingForceKillPIDCount) processes are still running after graceful termination. Force kill may lose unsaved work."
    }

    private var selectedAllowedProcesses: [ProcessMemoryItem] {
        processes.filter { selectedProcessIDs.contains($0.pid) && !$0.isProtected }
    }

    private var selectedAllowedPorts: [ListeningPort] {
        listeningPorts.filter { selectedPortIDs.contains($0.id) && !$0.isProtected }
    }

    private func performProcessRefresh() async {
        if processes.isEmpty {
            isLoading = true
        }

        let collector = processCollector
        let showAll = showAllMine
        let rows = maxRows
        let scope = scopeMode

        do {
            let (allMineRows, allRows) = try await Task.detached(priority: .userInitiated) {
                let mine = try collector.collectTopProcesses(limit: 10_000, scope: .sameUserOnly)
                let all = try collector.collectTopProcesses(limit: 10_000, scope: .allDiscoverable)
                return (mine, all)
            }.value

            guard !Task.isCancelled else { return }

            myProcessBytes = allMineRows.reduce(0) { $0 + $1.rankingBytes }
            allProcessBytes = allRows.reduce(0) { $0 + $1.rankingBytes }
            myProcessCount = allMineRows.count
            allProcessCount = allRows.count

            let mineRows = showAll ? allMineRows : Array(allMineRows.prefix(rows))

            let refreshed: [ProcessMemoryItem]
            switch scope {
            case .sameUserOnly:
                refreshed = mineRows
            case .allDiscoverable:
                refreshed = Array(allRows.prefix(rows))
            }

            processes = refreshed
            selectedProcessIDs = selectedProcessIDs.intersection(Set(refreshed.filter { !$0.isProtected }.map(\.pid)))
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func performPortsRefresh() async {
        if listeningPorts.isEmpty {
            isLoading = true
        }

        let collector = listeningPortCollector

        do {
            let refreshedPorts = try await Task.detached(priority: .userInitiated) {
                try collector.collectListeningPorts()
            }.value

            guard !Task.isCancelled else { return }

            listeningPorts = refreshedPorts
            selectedPortIDs = selectedPortIDs.intersection(Set(refreshedPorts.filter { !$0.isProtected }.map(\.id)))
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func terminateSelectedProcesses() async {
        let allowedIDs = Set(selectedAllowedProcesses.map(\.pid))

        guard !allowedIDs.isEmpty else {
            showingTerminateConfirmation = false
            return
        }

        isTerminating = true
        showingTerminateConfirmation = false

        // Yield so SwiftUI can observe the isTerminating state before
        // performing the synchronous kill() calls.
        await Task.yield()

        let summary = processTerminator.terminate(processes: processes, selectedProcessIDs: allowedIDs, signal: .terminate)
        resultMessage = summary.message
        selectedProcessIDs.removeAll()
        refresh()

        isTerminating = false
    }

    private func terminateSelectedPorts() async {
        let allowedPorts = selectedAllowedPorts
        let allowedPIDs = Set(allowedPorts.map(\.pid))

        guard !allowedPIDs.isEmpty else {
            showingTerminateConfirmation = false
            return
        }

        showingTerminateConfirmation = false
        isTerminating = true
        await Task.yield()

        let processLookup = buildProcessLookup(from: allowedPorts)
        let gracefulSummary = processTerminator.terminate(
            processes: Array(processLookup.values),
            selectedProcessIDs: allowedPIDs,
            signal: .terminate
        )
        let survivors = await waitForAlivePIDs(in: allowedPIDs)
        guard !Task.isCancelled else { return }

        if survivors.isEmpty {
            finalizePortsTermination(
                selectedPortCount: allowedPorts.count,
                processLookup: processLookup,
                gracefulSummary: gracefulSummary,
                survivorsAfterDecision: [],
                forceSummary: nil,
                forceDeclined: false
            )
            return
        }

        pendingPortsTerminationContext = PendingPortsTerminationContext(
            selectedPortCount: allowedPorts.count,
            processLookup: processLookup,
            gracefulSummary: gracefulSummary,
            survivors: survivors
        )
        pendingForceKillPIDCount = survivors.count
        showingForceKillConfirmation = true
        isTerminating = false
    }

    private func buildProcessLookup(from selectedPorts: [ListeningPort]) -> [Int32: ProcessMemoryItem] {
        var lookup: [Int32: ProcessMemoryItem] = [:]

        for row in selectedPorts {
            if lookup[row.pid] != nil {
                continue
            }

            lookup[row.pid] = ProcessMemoryItem(
                pid: row.pid,
                name: row.processName,
                userID: row.userID,
                userName: row.userName,
                residentBytes: 0,
                footprintBytes: nil,
                bsdFlags: 0,
                protectionReason: row.protectionReason
            )
        }

        return lookup
    }

    private func waitForAlivePIDs(in processIDs: Set<Int32>) async -> Set<Int32> {
        guard !processIDs.isEmpty else { return [] }

        var alive = processTerminator.aliveProcessIDs(in: processIDs)
        if alive.isEmpty {
            return []
        }

        let timeout = max(gracefulTimeoutSeconds, 0)
        let interval = max(pollIntervalSeconds, 0.001)
        let pollCount = max(1, Int(ceil(timeout / interval)))

        for _ in 0..<pollCount {
            await pollSleeper.sleep(seconds: interval)
            alive = processTerminator.aliveProcessIDs(in: alive)
            if alive.isEmpty {
                return []
            }
        }

        return alive
    }

    private func finalizePortsTermination(
        selectedPortCount: Int,
        processLookup: [Int32: ProcessMemoryItem],
        gracefulSummary: ProcessTerminationSummary,
        survivorsAfterDecision: Set<Int32>,
        forceSummary: ProcessTerminationSummary?,
        forceDeclined: Bool
    ) {
        let gracefulOutcomes = Dictionary(uniqueKeysWithValues: gracefulSummary.results.map { ($0.pid, $0.outcome) })
        let forceOutcomes = Dictionary(uniqueKeysWithValues: (forceSummary?.results ?? []).map { ($0.pid, $0.outcome) })

        var results: [ProcessTerminationResult] = []
        let orderedPIDs = processLookup.keys.sorted()
        results.reserveCapacity(orderedPIDs.count)

        for pid in orderedPIDs {
            guard let process = processLookup[pid] else { continue }

            let finalOutcome: ProcessTerminationOutcome
            if survivorsAfterDecision.contains(pid) {
                if forceDeclined {
                    finalOutcome = .skippedForceDeclined
                } else {
                    finalOutcome = .stillRunning
                }
            } else if let forceOutcome = forceOutcomes[pid] {
                finalOutcome = normalizedFinalOutcome(from: forceOutcome)
            } else if let gracefulOutcome = gracefulOutcomes[pid] {
                finalOutcome = normalizedFinalOutcome(from: gracefulOutcome)
            } else {
                finalOutcome = .terminated
            }

            results.append(
                ProcessTerminationResult(
                    pid: pid,
                    processName: process.name,
                    outcome: finalOutcome
                )
            )
        }

        let summary = ProcessTerminationSummary(results: results)
        let prefix = "Ports: \(selectedPortCount) selected, \(processLookup.count) unique PID(s)."
        resultMessage = "\(prefix) \(summary.message)"
        selectedPortIDs.removeAll()
        selectedProcessIDs.removeAll()
        isTerminating = false
        showingTerminateConfirmation = false
        showingForceKillConfirmation = false
        resetPendingPortsTermination()
        refresh()
    }

    private func normalizedFinalOutcome(from outcome: ProcessTerminationOutcome) -> ProcessTerminationOutcome {
        switch outcome {
        case .terminated, .notFound:
            return .terminated
        case .skippedProtected(let reason):
            return .skippedProtected(reason)
        case .permissionDenied:
            return .permissionDenied
        case .failed(let errno):
            return .failed(errno: errno)
        case .stillRunning:
            return .stillRunning
        case .skippedForceDeclined:
            return .skippedForceDeclined
        }
    }

    private func resetPendingPortsTermination() {
        pendingPortsTerminationContext = nil
        pendingForceKillPIDCount = 0
    }
}
