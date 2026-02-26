import Darwin
import Foundation

protocol CPUCollecting {
    func collect() -> CPUSnapshot
}

final class CPUCollector: CPUCollecting {
    private let smoothingAlpha: Double
    private var previousSample: (totalTicks: UInt64, idleTicks: UInt64)?
    private var smoothedPercent: Double?

    init(smoothingAlpha: Double = 0.35) {
        self.smoothingAlpha = min(max(smoothingAlpha, 0.05), 1.0)
    }

    func collect() -> CPUSnapshot {
        guard let sample = readSystemTicks() else {
            return .unavailable
        }

        guard let previousSample else {
            self.previousSample = sample
            return .unavailable
        }

        let totalDelta = sample.totalTicks >= previousSample.totalTicks
            ? sample.totalTicks - previousSample.totalTicks
            : 0
        let idleDelta = sample.idleTicks >= previousSample.idleTicks
            ? sample.idleTicks - previousSample.idleTicks
            : 0

        self.previousSample = sample

        guard totalDelta > 0 else {
            return CPUSnapshot(usagePercent: smoothedPercent)
        }

        let busyDelta = totalDelta >= idleDelta ? totalDelta - idleDelta : 0
        let rawPercent = (Double(busyDelta) / Double(totalDelta)) * 100

        let nextSmoothedPercent: Double
        if let smoothedPercent {
            nextSmoothedPercent = smoothedPercent + (rawPercent - smoothedPercent) * smoothingAlpha
        } else {
            nextSmoothedPercent = rawPercent
        }

        self.smoothedPercent = nextSmoothedPercent
        return CPUSnapshot(usagePercent: nextSmoothedPercent)
    }

    private func readSystemTicks() -> (totalTicks: UInt64, idleTicks: UInt64)? {
        var cpuInfoPointer: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0
        let hostPort = mach_host_self()

        defer {
            mach_port_deallocate(mach_task_self_, hostPort)
        }

        let result = host_processor_info(
            hostPort,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &cpuInfoPointer,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfoPointer else {
            return nil
        }

        defer {
            let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfoPointer), size)
        }

        let valueCount = Int(cpuInfoCount)
        let values = UnsafeBufferPointer(start: cpuInfoPointer, count: valueCount)
        let stride = Int(CPU_STATE_MAX)

        guard stride > 0, valueCount >= stride else {
            return nil
        }

        var total: UInt64 = 0
        var idle: UInt64 = 0
        var index = 0

        while index + stride <= valueCount {
            let user = UInt64(values[index + Int(CPU_STATE_USER)])
            let system = UInt64(values[index + Int(CPU_STATE_SYSTEM)])
            let nice = UInt64(values[index + Int(CPU_STATE_NICE)])
            let idleTicks = UInt64(values[index + Int(CPU_STATE_IDLE)])

            total += user + system + nice + idleTicks
            idle += idleTicks
            index += stride
        }

        return (total, idle)
    }
}
