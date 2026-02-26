import Darwin
import Foundation
import Security

final class BatteryHelperService: NSObject, NSXPCListenerDelegate, BatteryHelperXPCProtocol {
    private let listener: NSXPCListener
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let hardwareController = BatteryHardwareController()
    private let controlQueue = DispatchQueue(label: "com.oscar.macmonitor.helper.control")

    override init() {
        self.listener = NSXPCListener(machServiceName: BatteryHelperConstants.helperLabel)
        super.init()
    }

    func run() {
        listener.delegate = self
        listener.resume()
        dispatchMain()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard validateCallerIdentity(of: newConnection) else {
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: BatteryHelperXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    private func validateCallerIdentity(of connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        var code: SecCode?
        let attributes = [kSecGuestAttributePid: pid] as NSDictionary

        guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &code) == errSecSuccess,
              let clientCode = code else {
            return false
        }

        // Require the caller to be signed and to carry the MacMonitor bundle identifier.
        let requirementString = "identifier \"com.oscar.macmonitor\" and anchor apple generic"
        var requirement: SecRequirement?

        guard SecRequirementCreateWithString(requirementString as CFString, SecCSFlags(), &requirement) == errSecSuccess,
              let requirement = requirement else {
            return false
        }

        return SecCodeCheckValidity(clientCode, SecCSFlags(), requirement) == errSecSuccess
    }

    func execute(requestData: Data, withReply reply: @escaping (Data?, String?) -> Void) {
        guard let request = try? decoder.decode(BatteryHelperRequest.self, from: requestData) else {
            reply(nil, "Invalid request payload.")
            return
        }

        guard request.version == BatteryHelperConstants.protocolVersion else {
            reply(nil, "Unsupported protocol version \(request.version).")
            return
        }

        let response = handle(request: request)
        guard let responseData = try? encoder.encode(response) else {
            reply(nil, "Failed to encode response.")
            return
        }

        reply(responseData, nil)
    }

    private func handle(request: BatteryHelperRequest) -> BatteryHelperResponse {
        guard getuid() == 0 else {
            return BatteryHelperResponse(
                accepted: false,
                message: "Privileged helper is required. Please install helper with administrator privileges."
            )
        }

        switch request.command {
        case "setChargeLimit":
            guard let percent = request.intValue, (50...95).contains(percent) else {
                return BatteryHelperResponse(
                    accepted: false,
                    message: "Charge limit must be between 50 and 95 percent."
                )
            }
            return executeHardwareCommand {
                try self.hardwareController.setChargeLimit(percent)
            }

        case "startDischarge":
            guard let target = request.intValue, (50...95).contains(target) else {
                return BatteryHelperResponse(
                    accepted: false,
                    message: "Discharge target must be between 50 and 95 percent."
                )
            }
            return executeHardwareCommand {
                try self.hardwareController.startDischarge(targetPercent: target)
            }

        case "stopDischarge":
            return executeHardwareCommand {
                try self.hardwareController.stopDischarge()
            }

        case "startTopUp":
            return executeHardwareCommand {
                try self.hardwareController.startTopUp()
            }

        case "stopTopUp":
            return executeHardwareCommand {
                try self.hardwareController.stopTopUp()
            }

        case "setChargingPaused":
            guard let paused = request.boolValue else {
                return BatteryHelperResponse(
                    accepted: false,
                    message: "Missing paused flag."
                )
            }
            return executeHardwareCommand {
                try self.hardwareController.setChargingPaused(paused)
            }

        default:
            return BatteryHelperResponse(
                accepted: false,
                message: "Unsupported command: \(request.command)."
            )
        }
    }

    private func executeHardwareCommand(_ operation: @escaping () throws -> String) -> BatteryHelperResponse {
        controlQueue.sync {
            do {
                let message = try operation()
                return BatteryHelperResponse(accepted: true, message: message)
            } catch {
                return BatteryHelperResponse(accepted: false, message: error.localizedDescription)
            }
        }
    }
}
