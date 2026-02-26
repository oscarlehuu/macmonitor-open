import Foundation

enum BatteryIntentCommand {
    case setChargeLimit(Int)
    case pauseCharging
    case startTopUp
    case startDischarge(Int)
    case getState
}

struct BatteryIntentResponse {
    let accepted: Bool
    let message: String

    static func success(_ message: String) -> BatteryIntentResponse {
        BatteryIntentResponse(accepted: true, message: message)
    }

    static func failure(_ message: String) -> BatteryIntentResponse {
        BatteryIntentResponse(accepted: false, message: message)
    }
}

@MainActor
final class BatteryIntentBridge {
    static let shared = BatteryIntentBridge()

    var handler: ((BatteryIntentCommand) async -> BatteryIntentResponse)?

    private init() {}

    func perform(_ command: BatteryIntentCommand) async -> BatteryIntentResponse {
        guard let handler else {
            return .failure("Battery control is not initialized yet.")
        }
        return await handler(command)
    }
}
