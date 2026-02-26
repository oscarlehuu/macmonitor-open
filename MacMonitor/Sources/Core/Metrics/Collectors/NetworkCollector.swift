import Foundation
import SystemConfiguration

protocol NetworkCollecting {
    func collect() -> NetworkSnapshot
}

final class NetworkCollector: NetworkCollecting {
    private var previousCounters: (received: UInt64, sent: UInt64)?
    private var previousDate: Date?
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func collect() -> NetworkSnapshot {
        guard let counters = readNetworkCounters() else {
            return .unavailable
        }

        let sampleDate = now()
        defer {
            previousCounters = counters
            previousDate = sampleDate
        }

        guard let previousCounters, let previousDate else {
            return .unavailable
        }

        guard counters.received >= previousCounters.received,
              counters.sent >= previousCounters.sent else {
            // Interface reset or counter rollover. Re-baseline without emitting a spike.
            return .unavailable
        }

        let interval = sampleDate.timeIntervalSince(previousDate)
        guard interval > 0 else {
            return .unavailable
        }

        let receivedDelta = counters.received - previousCounters.received
        let sentDelta = counters.sent - previousCounters.sent

        return NetworkSnapshot(
            downloadBytesPerSecond: Double(receivedDelta) / interval,
            uploadBytesPerSecond: Double(sentDelta) / interval
        )
    }

    private func readNetworkCounters() -> (received: UInt64, sent: UInt64)? {
        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0

        var interfaceAddressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddressPointer) == 0 else {
            return nil
        }

        defer {
            freeifaddrs(interfaceAddressPointer)
        }

        guard let interfaceAddressPointer else {
            return nil
        }

        var cursor = interfaceAddressPointer
        while true {
            let interface = cursor.pointee
            if let address = interface.ifa_addr,
               Int32(address.pointee.sa_family) == AF_LINK,
               let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                // Skip loopback interface to avoid local traffic noise.
                let name = String(cString: interface.ifa_name)
                if name != "lo0" {
                    receivedBytes += UInt64(data.pointee.ifi_ibytes)
                    sentBytes += UInt64(data.pointee.ifi_obytes)
                }
            }

            guard let next = interface.ifa_next else { break }
            cursor = next
        }

        return (receivedBytes, sentBytes)
    }
}
