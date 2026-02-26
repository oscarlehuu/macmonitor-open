import Darwin
import Foundation

enum ProcessTerminationSignal: Equatable {
    case terminate
    case kill

    var rawSignal: Int32 {
        switch self {
        case .terminate:
            return SIGTERM
        case .kill:
            return SIGKILL
        }
    }
}

enum ProcessTerminationOutcome: Equatable {
    case terminated
    case skippedProtected(ProcessProtectionReason)
    case skippedForceDeclined
    case stillRunning
    case permissionDenied
    case notFound
    case failed(errno: Int32)
}

struct ProcessTerminationResult: Equatable {
    let pid: Int32
    let processName: String
    let outcome: ProcessTerminationOutcome

    var isSuccess: Bool {
        if case .terminated = outcome {
            return true
        }
        return false
    }

    var isSkipped: Bool {
        switch outcome {
        case .skippedProtected, .skippedForceDeclined:
            return true
        case .terminated, .stillRunning, .permissionDenied, .notFound, .failed:
            return false
        }
    }
}

struct ProcessTerminationSummary: Equatable {
    let results: [ProcessTerminationResult]

    var terminatedCount: Int {
        results.filter(\.isSuccess).count
    }

    var skippedCount: Int {
        results.filter(\.isSkipped).count
    }

    var failedCount: Int {
        results.count - terminatedCount - skippedCount
    }

    var stillRunningCount: Int {
        results.filter { result in
            if case .stillRunning = result.outcome {
                return true
            }
            return false
        }.count
    }

    var forceDeclinedCount: Int {
        results.filter { result in
            if case .skippedForceDeclined = result.outcome {
                return true
            }
            return false
        }.count
    }

    var message: String {
        var components = ["Terminated \(terminatedCount), skipped \(skippedCount), failed \(failedCount)."]
        if stillRunningCount > 0 {
            components.append("Still running: \(stillRunningCount).")
        }
        if forceDeclinedCount > 0 {
            components.append("Force declined: \(forceDeclinedCount).")
        }
        return components.joined(separator: " ")
    }
}

protocol ProcessTerminating {
    func terminate(
        processes: [ProcessMemoryItem],
        selectedProcessIDs: Set<Int32>,
        signal: ProcessTerminationSignal
    ) -> ProcessTerminationSummary
    func aliveProcessIDs(in processIDs: Set<Int32>) -> Set<Int32>
}

extension ProcessTerminating {
    func terminate(processes: [ProcessMemoryItem], selectedProcessIDs: Set<Int32>) -> ProcessTerminationSummary {
        terminate(processes: processes, selectedProcessIDs: selectedProcessIDs, signal: .terminate)
    }
}

struct SignalProcessTerminator: ProcessTerminating {
    typealias SignalSender = (_ pid: Int32, _ signal: Int32) -> (result: Int32, errno: Int32)

    private let signalSender: SignalSender

    init(signalSender: @escaping SignalSender = SignalProcessTerminator.defaultSignalSender) {
        self.signalSender = signalSender
    }

    func terminate(
        processes: [ProcessMemoryItem],
        selectedProcessIDs: Set<Int32>,
        signal: ProcessTerminationSignal
    ) -> ProcessTerminationSummary {
        let targets = processes.filter { selectedProcessIDs.contains($0.pid) }

        var results: [ProcessTerminationResult] = []
        results.reserveCapacity(targets.count)

        for process in targets {
            if let reason = process.protectionReason {
                results.append(
                    ProcessTerminationResult(
                        pid: process.pid,
                        processName: process.name,
                        outcome: .skippedProtected(reason)
                    )
                )
                continue
            }

            let signalResult = signalSender(process.pid, signal.rawSignal)
            if signalResult.result == 0 {
                results.append(
                    ProcessTerminationResult(
                        pid: process.pid,
                        processName: process.name,
                        outcome: .terminated
                    )
                )
                continue
            }

            let outcome: ProcessTerminationOutcome
            switch signalResult.errno {
            case EPERM:
                outcome = .permissionDenied
            case ESRCH:
                outcome = .notFound
            default:
                outcome = .failed(errno: signalResult.errno)
            }

            results.append(
                ProcessTerminationResult(
                    pid: process.pid,
                    processName: process.name,
                    outcome: outcome
                )
            )
        }

        return ProcessTerminationSummary(results: results)
    }

    func aliveProcessIDs(in processIDs: Set<Int32>) -> Set<Int32> {
        Set(
            processIDs.compactMap { pid in
                let result = signalSender(pid, 0)
                if result.result == 0 || result.errno == EPERM {
                    return pid
                }
                return nil
            }
        )
    }

    private static func defaultSignalSender(pid: Int32, signal: Int32) -> (result: Int32, errno: Int32) {
        let result = kill(pid, signal)
        return (result, Darwin.errno)
    }
}
