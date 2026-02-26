import Foundation

struct LsofListeningPortCollector: ListeningPortCollecting {
    typealias CommandExecutor = @Sendable (_ executablePath: String, _ arguments: [String]) throws -> (status: Int32, output: String)

    private let protectionPolicy: ProcessProtecting
    private let execute: CommandExecutor

    init(
        protectionPolicy: ProcessProtecting,
        execute: @escaping CommandExecutor = LsofListeningPortCollector.defaultExecute
    ) {
        self.protectionPolicy = protectionPolicy
        self.execute = execute
    }

    func collectListeningPorts() throws -> [ListeningPort] {
        let arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcunL"]
        let commandResult = try execute("/usr/sbin/lsof", arguments)
        guard commandResult.status == 0 else {
            throw ListeningPortCollectionError.commandFailed(status: commandResult.status)
        }
        return parse(output: commandResult.output)
    }

    private func parse(output: String) -> [ListeningPort] {
        var currentPID: Int32?
        var currentCommand: String?
        var currentUserID: uid_t?
        var currentUserName: String?
        var rowsByID: [String: ListeningPort] = [:]

        for rawLine in output.split(whereSeparator: \.isNewline) {
            guard let field = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())

            switch field {
            case "p":
                currentPID = Int32(value)
                currentCommand = nil
                currentUserID = nil
                currentUserName = nil
            case "c":
                currentCommand = value
            case "u":
                if let parsed = UInt32(value) {
                    currentUserID = uid_t(parsed)
                }
            case "L":
                currentUserName = value
            case "n":
                guard let pid = currentPID, let port = parsePort(from: value) else { continue }
                let userID = currentUserID ?? 0
                let processName = normalizedProcessName(currentCommand, pid: pid)
                let userName = (currentUserName?.isEmpty == false)
                    ? (currentUserName ?? String(userID))
                    : String(userID)
                let decision = protectionPolicy.evaluate(
                    processID: pid,
                    userID: userID,
                    flags: 0,
                    processName: processName
                )

                let row = ListeningPort(
                    protocolName: "TCP",
                    endpoint: value,
                    port: port,
                    pid: pid,
                    processName: processName,
                    userID: userID,
                    userName: userName,
                    protectionReason: decision.reason
                )
                rowsByID[row.id] = row
            default:
                continue
            }
        }

        return rowsByID.values.sorted { lhs, rhs in
            if lhs.port == rhs.port {
                if lhs.processName == rhs.processName {
                    if lhs.pid == rhs.pid {
                        return lhs.endpoint.localizedCaseInsensitiveCompare(rhs.endpoint) == .orderedAscending
                    }
                    return lhs.pid < rhs.pid
                }
                return lhs.processName.localizedCaseInsensitiveCompare(rhs.processName) == .orderedAscending
            }
            return lhs.port < rhs.port
        }
    }

    private func normalizedProcessName(_ processName: String?, pid: Int32) -> String {
        let trimmed = processName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return "pid-\(pid)"
        }
        return trimmed
    }

    private func parsePort(from endpoint: String) -> Int? {
        guard let separator = endpoint.lastIndex(of: ":") else { return nil }
        let suffix = endpoint[endpoint.index(after: separator)...]
        guard !suffix.isEmpty else { return nil }
        return Int(suffix)
    }

    private static func defaultExecute(executablePath: String, arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }
}
