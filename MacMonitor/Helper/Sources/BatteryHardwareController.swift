import Foundation

enum BatteryHardwareError: LocalizedError {
    case invalidPercent(Int)
    case unsupportedChargingControl
    case unsupportedAdapterControl
    case batteryDischargeUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPercent(let percent):
            return "Percentage \(percent)% is out of supported range (50-95%)."
        case .unsupportedChargingControl:
            return "Charging control keys are unavailable on this Mac."
        case .unsupportedAdapterControl:
            return "Adapter/discharge control keys are unavailable on this Mac."
        case .batteryDischargeUnavailable:
            return "Cannot force discharge on this Mac because adapter control is unavailable."
        }
    }
}

final class BatteryHardwareController {
    private enum ChargingControl {
        case legacyCH0
        case tahoeCHTE
        case unsupported
    }

    private enum AdapterControl {
        case ch0i
        case ch0j
        case chie
        case unsupported
    }

    private struct HardwareProfile {
        let chargingControl: ChargingControl
        let adapterControl: AdapterControl
    }

    private let smcClient: SMCClient
    // Safety gate: forced-adapter discharge writes can trigger unstable sleep/display behavior on some systems.
    private let allowUnsafeForcedDischarge: Bool

    init(
        smcClient: SMCClient = SMCClient(),
        allowUnsafeForcedDischarge: Bool = false
    ) {
        self.smcClient = smcClient
        self.allowUnsafeForcedDischarge = allowUnsafeForcedDischarge
    }

    func setChargeLimit(_ percent: Int) throws -> String {
        guard (50...95).contains(percent) else {
            throw BatteryHardwareError.invalidPercent(percent)
        }

        return try smcClient.withConnection { client in
            let profile = try detectProfile(using: client)
            let currentPercent = try? readBatteryPercent(using: client)

            try clearForcedDischarge(using: client, profile: profile)

            if let currentPercent, currentPercent > percent {
                try disableCharging(using: client, profile: profile)
                return "Charge limit \(percent)% applied. Battery is \(currentPercent)% so charging is paused."
            }

            try enableCharging(using: client, profile: profile)
            if let currentPercent {
                return "Charge limit \(percent)% applied. Battery is \(currentPercent)% so charging is enabled."
            }
            return "Charge limit \(percent)% applied."
        }
    }

    func startDischarge(targetPercent: Int) throws -> String {
        guard (50...95).contains(targetPercent) else {
            throw BatteryHardwareError.invalidPercent(targetPercent)
        }

        return try smcClient.withConnection { client in
            let profile = try detectProfile(using: client)
            // Always clear any previous forced-discharge state first.
            try clearForcedDischarge(using: client, profile: profile)
            try disableCharging(using: client, profile: profile)

            if allowUnsafeForcedDischarge {
                guard profile.adapterControl != .unsupported else {
                    throw BatteryHardwareError.batteryDischargeUnavailable
                }
                try enableForcedDischarge(using: client, profile: profile)
                return "Forced discharge started toward \(targetPercent)%."
            }

            return "Discharge mode enabled toward \(targetPercent)%; charging paused (safe mode)."
        }
    }

    func stopDischarge() throws -> String {
        try smcClient.withConnection { client in
            let profile = try detectProfile(using: client)
            try clearForcedDischarge(using: client, profile: profile)
            try disableCharging(using: client, profile: profile)
            return "Forced discharge stopped; charging remains paused."
        }
    }

    func setChargingPaused(_ paused: Bool) throws -> String {
        try smcClient.withConnection { client in
            let profile = try detectProfile(using: client)
            try clearForcedDischarge(using: client, profile: profile)

            if paused {
                try disableCharging(using: client, profile: profile)
                return "Charging paused."
            } else {
                try enableCharging(using: client, profile: profile)
                return "Charging resumed."
            }
        }
    }

    func startTopUp() throws -> String {
        try smcClient.withConnection { client in
            let profile = try detectProfile(using: client)
            try clearForcedDischarge(using: client, profile: profile)
            try enableCharging(using: client, profile: profile)
            return "Top Up enabled; charging to 100%."
        }
    }

    func stopTopUp() throws -> String {
        try smcClient.withConnection { client in
            let profile = try detectProfile(using: client)
            try clearForcedDischarge(using: client, profile: profile)
            try disableCharging(using: client, profile: profile)
            return "Top Up disabled; charging paused."
        }
    }

    private func detectProfile(using client: SMCClient) throws -> HardwareProfile {
        let chargingControl: ChargingControl
        if try client.keyExists("CHTE") {
            chargingControl = .tahoeCHTE
        } else if try client.keyExists("CH0B"), try client.keyExists("CH0C") {
            chargingControl = .legacyCH0
        } else {
            chargingControl = .unsupported
        }

        let adapterControl: AdapterControl
        if try client.keyExists("CHIE") {
            adapterControl = .chie
        } else if try client.keyExists("CH0J") {
            adapterControl = .ch0j
        } else if try client.keyExists("CH0I") {
            adapterControl = .ch0i
        } else {
            adapterControl = .unsupported
        }

        return HardwareProfile(chargingControl: chargingControl, adapterControl: adapterControl)
    }

    private func enableCharging(using client: SMCClient, profile: HardwareProfile) throws {
        switch profile.chargingControl {
        case .legacyCH0:
            try client.write(key: "CH0B", bytes: [0x00])
            try client.write(key: "CH0C", bytes: [0x00])
        case .tahoeCHTE:
            try client.write(key: "CHTE", bytes: [0x00, 0x00, 0x00, 0x00])
        case .unsupported:
            throw BatteryHardwareError.unsupportedChargingControl
        }
    }

    private func disableCharging(using client: SMCClient, profile: HardwareProfile) throws {
        switch profile.chargingControl {
        case .legacyCH0:
            try client.write(key: "CH0B", bytes: [0x02])
            try client.write(key: "CH0C", bytes: [0x02])
        case .tahoeCHTE:
            try client.write(key: "CHTE", bytes: [0x01, 0x00, 0x00, 0x00])
        case .unsupported:
            throw BatteryHardwareError.unsupportedChargingControl
        }
    }

    private func enableForcedDischarge(using client: SMCClient, profile: HardwareProfile) throws {
        switch profile.adapterControl {
        case .chie:
            try client.write(key: "CHIE", bytes: [0x08])
        case .ch0j:
            try client.write(key: "CH0J", bytes: [0x01])
        case .ch0i:
            try client.write(key: "CH0I", bytes: [0x01])
        case .unsupported:
            throw BatteryHardwareError.unsupportedAdapterControl
        }
    }

    private func clearForcedDischarge(using client: SMCClient, profile: HardwareProfile) throws {
        switch profile.adapterControl {
        case .chie:
            try client.write(key: "CHIE", bytes: [0x00])
        case .ch0j:
            try client.write(key: "CH0J", bytes: [0x00])
        case .ch0i:
            try client.write(key: "CH0I", bytes: [0x00])
        case .unsupported:
            break
        }
    }

    private func readBatteryPercent(using client: SMCClient) throws -> Int? {
        do {
            let bytes = try client.read(key: "BUIC")
            guard let byte = bytes.first else { return nil }
            return Int(byte)
        } catch SMCClientError.keyNotFound {
            return nil
        }
    }
}
