import Darwin
import Foundation

enum ProcessProtectionReason: String, Equatable {
    case currentApplication
    case kernelReserved
    case systemProcess
    case differentOwner
    case criticalName

    var description: String {
        switch self {
        case .currentApplication:
            return "Current app"
        case .kernelReserved:
            return "Reserved PID"
        case .systemProcess:
            return "System process"
        case .differentOwner:
            return "Different user"
        case .criticalName:
            return "Critical process"
        }
    }
}

struct ProcessProtectionDecision: Equatable {
    let isProtected: Bool
    let reason: ProcessProtectionReason?

    static let allow = ProcessProtectionDecision(isProtected: false, reason: nil)

    static func deny(_ reason: ProcessProtectionReason) -> ProcessProtectionDecision {
        ProcessProtectionDecision(isProtected: true, reason: reason)
    }
}

protocol ProcessProtecting: Sendable {
    func evaluate(processID: Int32, userID: uid_t, flags: UInt32, processName: String) -> ProcessProtectionDecision
}

struct DefaultProcessProtectionPolicy: ProcessProtecting {
    private let currentProcessID: Int32
    private let currentUserID: uid_t
    private let criticalNames: Set<String>

    init(
        currentProcessID: Int32 = getpid(),
        currentUserID: uid_t = getuid(),
        criticalNames: Set<String> = [
            "kernel_task",
            "launchd",
            "windowserver",
            "loginwindow",
            "syslogd",
            "notifyd",
            "powerd",
            "coreaudiod"
        ]
    ) {
        self.currentProcessID = currentProcessID
        self.currentUserID = currentUserID
        self.criticalNames = Set(criticalNames.map { $0.lowercased() })
    }

    func evaluate(processID: Int32, userID: uid_t, flags: UInt32, processName: String) -> ProcessProtectionDecision {
        if processID <= 1 {
            return .deny(.kernelReserved)
        }

        if processID == currentProcessID {
            return .deny(.currentApplication)
        }

        if (flags & UInt32(PROC_FLAG_SYSTEM)) != 0 {
            return .deny(.systemProcess)
        }

        if userID != currentUserID {
            return .deny(.differentOwner)
        }

        if criticalNames.contains(processName.lowercased()) {
            return .deny(.criticalName)
        }

        return .allow
    }
}
