import Darwin
import Foundation

enum RAMDetailsMode: String, CaseIterable, Identifiable {
    case processes
    case ports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .processes:
            return "Processes"
        case .ports:
            return "Ports"
        }
    }
}

struct ListeningPort: Identifiable, Equatable {
    let protocolName: String
    let endpoint: String
    let port: Int
    let pid: Int32
    let processName: String
    let userID: uid_t
    let userName: String
    let protectionReason: ProcessProtectionReason?

    var id: String {
        "\(pid):\(endpoint)"
    }

    var isProtected: Bool {
        protectionReason != nil
    }
}

enum ListeningPortCollectionError: LocalizedError, Equatable {
    case commandFailed(status: Int32)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let status):
            return "Unable to collect listening ports (exit \(status))."
        }
    }
}

protocol ListeningPortCollecting: Sendable {
    func collectListeningPorts() throws -> [ListeningPort]
}
