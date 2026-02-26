import Foundation

enum BatteryControlAvailability: Equatable {
    case available
    case unavailable(reason: String)
}

enum BatteryControlCommand: Equatable, Hashable, Codable {
    case setChargeLimit(Int)
    case startDischarge(targetPercent: Int)
    case stopDischarge
    case setChargingPaused(Bool)
    case startTopUp
    case stopTopUp

    private enum CodingKeys: String, CodingKey {
        case kind
        case intValue
        case boolValue
    }

    private enum Kind: String, Codable {
        case setChargeLimit
        case startDischarge
        case stopDischarge
        case setChargingPaused
        case startTopUp
        case stopTopUp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .setChargeLimit:
            let limit = try container.decode(Int.self, forKey: .intValue)
            self = .setChargeLimit(limit)
        case .startDischarge:
            let target = try container.decode(Int.self, forKey: .intValue)
            self = .startDischarge(targetPercent: target)
        case .stopDischarge:
            self = .stopDischarge
        case .setChargingPaused:
            let paused = try container.decode(Bool.self, forKey: .boolValue)
            self = .setChargingPaused(paused)
        case .startTopUp:
            self = .startTopUp
        case .stopTopUp:
            self = .stopTopUp
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .setChargeLimit(let limit):
            try container.encode(Kind.setChargeLimit, forKey: .kind)
            try container.encode(limit, forKey: .intValue)
        case .startDischarge(let targetPercent):
            try container.encode(Kind.startDischarge, forKey: .kind)
            try container.encode(targetPercent, forKey: .intValue)
        case .stopDischarge:
            try container.encode(Kind.stopDischarge, forKey: .kind)
        case .setChargingPaused(let paused):
            try container.encode(Kind.setChargingPaused, forKey: .kind)
            try container.encode(paused, forKey: .boolValue)
        case .startTopUp:
            try container.encode(Kind.startTopUp, forKey: .kind)
        case .stopTopUp:
            try container.encode(Kind.stopTopUp, forKey: .kind)
        }
    }
}

struct BatteryControlCommandResult: Equatable {
    let accepted: Bool
    let message: String?

    static func success(_ message: String? = nil) -> BatteryControlCommandResult {
        BatteryControlCommandResult(accepted: true, message: message)
    }

    static func failure(_ message: String) -> BatteryControlCommandResult {
        BatteryControlCommandResult(accepted: false, message: message)
    }
}

protocol BatteryControlBackend {
    var availability: BatteryControlAvailability { get }
    func execute(_ command: BatteryControlCommand) -> BatteryControlCommandResult
    func installHelperIfNeeded() -> BatteryControlCommandResult
}

struct UnsupportedBatteryControlBackend: BatteryControlBackend {
    let reason: String

    var availability: BatteryControlAvailability {
        .unavailable(reason: reason)
    }

    func execute(_ command: BatteryControlCommand) -> BatteryControlCommandResult {
        .failure(reason)
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        .failure(reason)
    }
}
