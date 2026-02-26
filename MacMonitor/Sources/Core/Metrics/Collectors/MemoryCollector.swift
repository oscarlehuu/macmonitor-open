import Darwin
import Foundation

protocol MemoryCollecting {
    func collect() -> MemorySnapshot?
}

struct MemoryCollector: MemoryCollecting {
    static func usedPageCount(from stats: vm_statistics64) -> UInt64 {
        // "Used" in the RAM headline follows the app formula: Active + Wired.
        UInt64(stats.active_count) + UInt64(stats.wire_count)
    }

    func collect() -> MemorySnapshot? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let hostPort: mach_port_t = mach_host_self()
        var pageSize: vm_size_t = 0

        let pageSizeResult = host_page_size(hostPort, &pageSize)
        guard pageSizeResult == KERN_SUCCESS, pageSize > 0 else {
            return nil
        }

        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, reboundPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let inactiveBytes = UInt64(stats.inactive_count) * UInt64(pageSize)
        let compressedBytes = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        let freeBytes = UInt64(stats.free_count) * UInt64(pageSize)
        let usedPages = Self.usedPageCount(from: stats)
        let usedBytes = min(totalBytes, usedPages * UInt64(pageSize))

        let freePages = UInt64(stats.free_count)
        let totalPages = max(1, UInt64(totalBytes / UInt64(pageSize)))
        let freeRatio = Double(freePages) / Double(totalPages)

        let pressure: MemoryPressureLevel
        switch freeRatio {
        case ..<0.04:
            pressure = .critical
        case ..<0.10:
            pressure = .warning
        default:
            pressure = .normal
        }

        return MemorySnapshot(
            usedBytes: usedBytes,
            totalBytes: totalBytes,
            pressure: pressure,
            inactiveBytes: inactiveBytes,
            compressedBytes: compressedBytes,
            freeBytes: freeBytes
        )
    }
}
