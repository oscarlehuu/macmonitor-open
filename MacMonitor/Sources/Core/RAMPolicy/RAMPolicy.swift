import Foundation

enum RAMPolicyLimitMode: String, Codable, CaseIterable, Identifiable {
    case percent
    case gigabytes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percent:
            return "%"
        case .gigabytes:
            return "GB"
        }
    }
}

enum RAMPolicyTriggerMode: String, Codable, CaseIterable, Identifiable {
    case immediate
    case sustained
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immediate:
            return "Immediate"
        case .sustained:
            return "Sustained"
        case .both:
            return "Both"
        }
    }

    var includesImmediate: Bool {
        self == .immediate || self == .both
    }

    var includesSustained: Bool {
        self == .sustained || self == .both
    }
}

struct RAMPolicy: Identifiable, Codable, Equatable {
    static let defaultSustainedSeconds = 15
    static let defaultCooldownSeconds = 300

    let id: UUID
    var bundleID: String
    var displayName: String
    var limitMode: RAMPolicyLimitMode
    var limitValue: Double
    var triggerMode: RAMPolicyTriggerMode
    var sustainedSeconds: Int
    var notifyCooldownSeconds: Int
    var enabled: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bundleID: String,
        displayName: String,
        limitMode: RAMPolicyLimitMode,
        limitValue: Double,
        triggerMode: RAMPolicyTriggerMode,
        sustainedSeconds: Int = RAMPolicy.defaultSustainedSeconds,
        notifyCooldownSeconds: Int = RAMPolicy.defaultCooldownSeconds,
        enabled: Bool = true,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bundleID = bundleID
        self.displayName = displayName
        self.limitMode = limitMode
        self.limitValue = limitValue
        self.triggerMode = triggerMode
        self.sustainedSeconds = sustainedSeconds
        self.notifyCooldownSeconds = notifyCooldownSeconds
        self.enabled = enabled
        self.updatedAt = updatedAt
    }

    var normalized: RAMPolicy {
        var copy = self

        copy.bundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.displayName = trimmedName.isEmpty ? copy.bundleID : trimmedName

        if limitMode == .percent {
            copy.limitValue = max(0.1, min(limitValue, 100))
        } else {
            copy.limitValue = max(0.1, limitValue)
        }

        copy.sustainedSeconds = max(1, sustainedSeconds)
        copy.notifyCooldownSeconds = max(0, notifyCooldownSeconds)

        return copy
    }

    var isValid: Bool {
        guard !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        switch limitMode {
        case .percent:
            guard limitValue > 0, limitValue <= 100 else { return false }
        case .gigabytes:
            guard limitValue > 0 else { return false }
        }

        guard sustainedSeconds >= 1 else { return false }
        guard notifyCooldownSeconds >= 0 else { return false }

        return true
    }

    func thresholdBytes(totalMemoryBytes: UInt64) -> UInt64 {
        switch limitMode {
        case .percent:
            let ratio = max(0, min(limitValue, 100)) / 100.0
            let threshold = UInt64((Double(totalMemoryBytes) * ratio).rounded())
            return max(1, threshold)
        case .gigabytes:
            let bytesPerGigabyte = Double(1024 * 1024 * 1024)
            let threshold = UInt64((max(0, limitValue) * bytesPerGigabyte).rounded())
            return max(1, threshold)
        }
    }

    var thresholdDescription: String {
        switch limitMode {
        case .percent:
            let rounded = (limitValue * 10).rounded() / 10
            if rounded.rounded() == rounded {
                return "\(Int(rounded))%"
            }
            return "\(rounded)%"
        case .gigabytes:
            let rounded = (limitValue * 10).rounded() / 10
            if rounded.rounded() == rounded {
                return "\(Int(rounded)) GB"
            }
            return "\(rounded) GB"
        }
    }
}
