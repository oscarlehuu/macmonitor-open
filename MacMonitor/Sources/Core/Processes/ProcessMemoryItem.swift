import Darwin
import Foundation

struct ProcessMemoryItem: Identifiable, Equatable {
    let pid: Int32
    let name: String
    let userID: uid_t
    let userName: String
    let residentBytes: UInt64
    let footprintBytes: UInt64?
    let bsdFlags: UInt32
    let protectionReason: ProcessProtectionReason?

    var id: Int32 { pid }

    var isProtected: Bool {
        protectionReason != nil
    }

    var rankingBytes: UInt64 {
        if let footprintBytes, footprintBytes > 0 {
            return footprintBytes
        }
        return residentBytes
    }

    var metricLabel: String {
        if let footprintBytes, footprintBytes > 0 {
            return "Footprint"
        }
        return "Resident"
    }

    /// Canonical sort order: descending by `rankingBytes`, then ascending
    /// case-insensitive name, then ascending pid as final tiebreaker.
    static func rankDescending(_ lhs: ProcessMemoryItem, _ rhs: ProcessMemoryItem) -> Bool {
        if lhs.rankingBytes == rhs.rankingBytes {
            if lhs.name == rhs.name {
                return lhs.pid < rhs.pid
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.rankingBytes > rhs.rankingBytes
    }
}
