import Foundation

final class XPCBatteryControlBackend: BatteryControlBackend {
    private let serviceName: String
    private let helperInstaller: BatteryHelperInstalling
    private let timeout: TimeInterval
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        serviceName: String = BatteryHelperXPCConstants.helperLabel,
        helperInstaller: BatteryHelperInstalling,
        timeout: TimeInterval = 1.0
    ) {
        self.serviceName = serviceName
        self.helperInstaller = helperInstaller
        self.timeout = max(0.2, timeout)
    }

    var availability: BatteryControlAvailability {
        helperInstaller.isHelperInstalled()
        ? .available
        : .unavailable(reason: "Battery helper is not installed.")
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        if helperInstaller.isHelperInstalled() {
            return .success("Battery helper is already installed.")
        }

        switch helperInstaller.installHelper() {
        case .success(.privileged):
            return .success("Privileged helper installed.")
        case .success(.privilegedLaunchDaemon):
            return .success("Privileged helper installed via LaunchDaemon.")
        case .failure(let error):
            return .failure(error.localizedDescription)
        }
    }

    func execute(_ command: BatteryControlCommand) -> BatteryControlCommandResult {
        let currentAvailability = availability
        guard case .available = currentAvailability else {
            if case .unavailable(let reason) = currentAvailability {
                return .failure(reason)
            }
            return .failure("Battery helper unavailable.")
        }

        guard let requestData = try? encoder.encode(BatteryControlXPCRequest(command: command)) else {
            return .failure("Unable to encode battery command request.")
        }

        return executeViaXPC(requestData: requestData, options: .privileged)
    }

    private func executeViaXPC(
        requestData: Data,
        options: NSXPCConnection.Options
    ) -> BatteryControlCommandResult {
        let connection = NSXPCConnection(machServiceName: serviceName, options: options)
        connection.remoteObjectInterface = NSXPCInterface(with: BatteryHelperXPCProtocol.self)
        connection.resume()
        defer {
            connection.invalidate()
        }

        let semaphore = DispatchSemaphore(value: 0)
        var commandResult: BatteryControlCommandResult?

        let errorHandler: (Error) -> Void = { error in
            commandResult = .failure("XPC error: \(error.localizedDescription)")
            semaphore.signal()
        }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler(errorHandler) as? BatteryHelperXPCProtocol else {
            return .failure("Unable to acquire helper XPC proxy.")
        }

        proxy.execute(requestData: requestData) { responseData, errorMessage in
            defer { semaphore.signal() }

            if let errorMessage {
                commandResult = .failure(errorMessage)
                return
            }

            guard let responseData else {
                commandResult = .failure("Helper returned an empty response.")
                return
            }

            guard let response = try? self.decoder.decode(BatteryControlXPCResponse.self, from: responseData) else {
                commandResult = .failure("Unable to decode helper response.")
                return
            }

            if response.accepted {
                commandResult = .success(response.message)
            } else {
                commandResult = .failure(response.message ?? "Helper rejected command.")
            }
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            return .failure("Timed out waiting for helper response.")
        }

        return commandResult ?? .failure("No helper response received.")
    }
}
