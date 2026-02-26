import Foundation

enum BatteryHelperXPCConstants {
    static let helperLabel = "com.oscar.macmonitor.battery-helper"
    static let protocolVersion = 1
}

struct BatteryControlXPCRequest: Codable {
    let version: Int
    let command: String
    let intValue: Int?
    let boolValue: Bool?

    init(command: BatteryControlCommand) {
        self.version = BatteryHelperXPCConstants.protocolVersion

        switch command {
        case .setChargeLimit(let percent):
            self.command = "setChargeLimit"
            self.intValue = percent
            self.boolValue = nil
        case .startDischarge(let targetPercent):
            self.command = "startDischarge"
            self.intValue = targetPercent
            self.boolValue = nil
        case .stopDischarge:
            self.command = "stopDischarge"
            self.intValue = nil
            self.boolValue = nil
        case .setChargingPaused(let paused):
            self.command = "setChargingPaused"
            self.intValue = nil
            self.boolValue = paused
        case .startTopUp:
            self.command = "startTopUp"
            self.intValue = nil
            self.boolValue = nil
        case .stopTopUp:
            self.command = "stopTopUp"
            self.intValue = nil
            self.boolValue = nil
        }
    }
}

struct BatteryControlXPCResponse: Codable {
    let accepted: Bool
    let message: String?
}

@objc protocol BatteryHelperXPCProtocol {
    func execute(requestData: Data, withReply reply: @escaping (Data?, String?) -> Void)
}
