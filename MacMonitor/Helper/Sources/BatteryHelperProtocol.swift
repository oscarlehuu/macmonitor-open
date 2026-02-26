import Foundation

enum BatteryHelperConstants {
    static let helperLabel = "com.oscar.macmonitor.battery-helper"
    static let protocolVersion = 1
}

struct BatteryHelperRequest: Codable {
    let version: Int
    let command: String
    let intValue: Int?
    let boolValue: Bool?
}

struct BatteryHelperResponse: Codable {
    let accepted: Bool
    let message: String?
}

@objc protocol BatteryHelperXPCProtocol {
    func execute(requestData: Data, withReply reply: @escaping (Data?, String?) -> Void)
}
