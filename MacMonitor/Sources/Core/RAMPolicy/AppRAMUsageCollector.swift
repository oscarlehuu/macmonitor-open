import Darwin
import Foundation

struct AppRAMUsage: Identifiable, Equatable {
    let bundleID: String
    let displayName: String
    let usedBytes: UInt64

    var id: String { bundleID }
}

enum AppRAMCollectionError: LocalizedError {
    case pidEnumerationFailed

    var errorDescription: String? {
        switch self {
        case .pidEnumerationFailed:
            return "Unable to collect per-app RAM usage."
        }
    }
}

protocol RunningAppRAMCollecting {
    func collectUsageByApp() throws -> [AppRAMUsage]
}

struct LibprocAppRAMCollector: RunningAppRAMCollecting {
    func collectUsageByApp() throws -> [AppRAMUsage] {
        var pids = [pid_t](repeating: 0, count: 4096)
        let bufferBytes = Int32(pids.count * MemoryLayout<pid_t>.stride)
        let bytesWritten = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferBytes)
        guard bytesWritten > 0 else {
            throw AppRAMCollectionError.pidEnumerationFailed
        }

        let pidCount = min(Int(bytesWritten) / MemoryLayout<pid_t>.stride, pids.count)
        var usageByBundleID: [String: (displayName: String, bytes: UInt64)] = [:]
        var bundleCache: [String: (bundleID: String?, displayName: String)] = [:]

        for pid in pids.prefix(pidCount) where pid > 1 {
            guard let processBytes = rankingBytes(for: pid) else { continue }
            guard let executablePath = executablePath(for: pid) else { continue }
            guard let appBundlePath = appBundlePath(from: executablePath) else { continue }

            let bundleInfo: (bundleID: String?, displayName: String)
            if let cached = bundleCache[appBundlePath] {
                bundleInfo = cached
            } else {
                bundleInfo = resolveBundleInfo(appBundlePath: appBundlePath)
                bundleCache[appBundlePath] = bundleInfo
            }

            guard let bundleID = bundleInfo.bundleID, !bundleID.isEmpty else { continue }

            let existing = usageByBundleID[bundleID] ?? (bundleInfo.displayName, 0)
            usageByBundleID[bundleID] = (existing.displayName, existing.bytes + processBytes)
        }

        return usageByBundleID
            .map { bundleID, item in
                AppRAMUsage(bundleID: bundleID, displayName: item.displayName, usedBytes: item.bytes)
            }
            .sorted { lhs, rhs in
                if lhs.usedBytes == rhs.usedBytes {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.usedBytes > rhs.usedBytes
            }
    }

    private func rankingBytes(for pid: pid_t) -> UInt64? {
        var taskInfo = proc_taskallinfo()
        let bytesRead = withUnsafeMutableBytes(of: &taskInfo) { rawBuffer in
            proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, rawBuffer.baseAddress, Int32(rawBuffer.count))
        }

        guard bytesRead == Int32(MemoryLayout<proc_taskallinfo>.stride) else {
            return nil
        }

        if let footprint = footprintBytes(for: pid), footprint > 0 {
            return footprint
        }

        return taskInfo.ptinfo.pti_resident_size
    }

    private func footprintBytes(for pid: pid_t) -> UInt64? {
        var usage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &usage) { usagePtr in
            usagePtr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPtr in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, reboundPtr)
            }
        }

        guard result == 0, usage.ri_phys_footprint > 0 else {
            return nil
        }

        return usage.ri_phys_footprint
    }

    private func executablePath(for pid: pid_t) -> String? {
        let pathBufferSize = 4096
        var pathBuffer = [CChar](repeating: 0, count: pathBufferSize)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard pathLength > 0 else {
            return nil
        }

        let bytes = pathBuffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        let path = String(decoding: bytes, as: UTF8.self)
        return path.isEmpty ? nil : path
    }

    private func appBundlePath(from executablePath: String) -> String? {
        guard let markerRange = executablePath.range(of: ".app/", options: .caseInsensitive)
                ?? executablePath.range(of: ".app", options: [.caseInsensitive, .backwards]) else {
            return nil
        }

        let appEndIndex = executablePath.index(markerRange.lowerBound, offsetBy: 4)
        let prefix = executablePath[..<appEndIndex]

        guard let firstSlashIndex = prefix.firstIndex(of: "/") else {
            return nil
        }

        return String(prefix[firstSlashIndex...])
    }

    private func resolveBundleInfo(appBundlePath: String) -> (bundleID: String?, displayName: String) {
        let bundleURL = URL(fileURLWithPath: appBundlePath, isDirectory: true)
        let fallbackName = bundleURL.deletingPathExtension().lastPathComponent

        guard let bundle = Bundle(url: bundleURL) else {
            return (nil, fallbackName)
        }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? fallbackName

        return (bundle.bundleIdentifier, displayName)
    }
}
