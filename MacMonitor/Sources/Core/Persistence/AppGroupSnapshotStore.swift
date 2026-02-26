import Foundation

struct SharedSnapshotPoint: Codable, Equatable {
    let timestamp: Date
    let thermalState: ThermalState
    let memoryUsagePercent: Double
    let storageUsagePercent: Double
    let batteryPercent: Int?
    let cpuUsagePercent: Double?
    let networkDownloadBytesPerSecond: Double?
    let networkUploadBytesPerSecond: Double?
}

struct SharedSnapshotSummary: Codable, Equatable {
    let schemaVersion: SnapshotSchemaVersion
    let generatedAt: Date
    let latest: SharedSnapshotPoint
    let trend24Hours: [SharedSnapshotPoint]
    let trend7Days: [SharedSnapshotPoint]
}

final class AppGroupSnapshotStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.oscar.macmonitor.app-group-snapshot-store")

    init(
        fileManager: FileManager = .default,
        appGroupID: String = "group.com.oscar.macmonitor",
        fallbackBaseDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager

        if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            directoryURL = appGroupURL.appendingPathComponent("Snapshots", isDirectory: true)
        } else if let fallbackBaseDirectoryURL {
            directoryURL = fallbackBaseDirectoryURL.appendingPathComponent("Snapshots", isDirectory: true)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            directoryURL = appSupport
                .appendingPathComponent("MacMonitor", isDirectory: true)
                .appendingPathComponent("SharedSnapshots", isDirectory: true)
        }

        fileURL = directoryURL.appendingPathComponent("shared-snapshot-v2.json")

        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        ensureDirectoryExists()
    }

    func write(snapshot: SystemSnapshot, history: [SystemSnapshot], referenceDate: Date = Date()) {
        queue.sync {
            ensureDirectoryExists()

            let latest = makePoint(from: snapshot)
            let recent24h = projectedPoints(
                from: history + [snapshot],
                since: referenceDate.addingTimeInterval(-24 * 60 * 60),
                maxPoints: 96
            )
            let recent7d = projectedPoints(
                from: history + [snapshot],
                since: referenceDate.addingTimeInterval(-7 * 24 * 60 * 60),
                maxPoints: 168
            )

            let payload = SharedSnapshotSummary(
                schemaVersion: .v2,
                generatedAt: referenceDate,
                latest: latest,
                trend24Hours: recent24h,
                trend7Days: recent7d
            )

            guard let data = try? encoder.encode(payload) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func loadSummary() -> SharedSnapshotSummary? {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return try? decoder.decode(SharedSnapshotSummary.self, from: data)
        }
    }

    private func makePoint(from snapshot: SystemSnapshot) -> SharedSnapshotPoint {
        SharedSnapshotPoint(
            timestamp: snapshot.timestamp,
            thermalState: snapshot.thermal.state,
            memoryUsagePercent: snapshot.memory.usageRatio * 100,
            storageUsagePercent: snapshot.storage.usageRatio * 100,
            batteryPercent: snapshot.battery.percentage,
            cpuUsagePercent: snapshot.cpu.normalizedPercent,
            networkDownloadBytesPerSecond: snapshot.network.downloadBytesPerSecond,
            networkUploadBytesPerSecond: snapshot.network.uploadBytesPerSecond
        )
    }

    private func projectedPoints(
        from snapshots: [SystemSnapshot],
        since cutoffDate: Date,
        maxPoints: Int
    ) -> [SharedSnapshotPoint] {
        let filtered = snapshots
            .filter { $0.timestamp >= cutoffDate }
            .sorted(by: { $0.timestamp < $1.timestamp })

        guard filtered.count > maxPoints, maxPoints > 0 else {
            return filtered.map(makePoint(from:))
        }

        // Uniform downsampling by stride for lightweight widget timeline rendering.
        let stride = max(1, Int(ceil(Double(filtered.count) / Double(maxPoints))))
        var points: [SharedSnapshotPoint] = []
        points.reserveCapacity(maxPoints)

        var index = 0
        while index < filtered.count {
            points.append(makePoint(from: filtered[index]))
            index += stride
        }
        if let last = filtered.last {
            let lastPoint = makePoint(from: last)
            if points.last?.timestamp != lastPoint.timestamp {
                points.append(lastPoint)
            }
        }
        return points
    }

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
