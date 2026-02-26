import Foundation

enum MenuBarDisplayFormatter {
    static func valueText(
        for snapshot: SystemSnapshot?,
        mode: MenuBarDisplayMode,
        memoryFormat: MenuBarMetricDisplayFormat,
        storageFormat: MenuBarMetricDisplayFormat
    ) -> String? {
        let memoryText = metricText(
            usedBytes: snapshot?.memory.usedBytes,
            totalBytes: snapshot?.memory.totalBytes,
            format: memoryFormat
        )
        let storageText = metricText(
            usedBytes: snapshot?.storage.usedBytes,
            totalBytes: snapshot?.storage.totalBytes,
            format: storageFormat
        )
        let cpuText = MetricFormatter.percentValue(snapshot?.cpu.normalizedPercent)
        let networkDownText = MetricFormatter.bytesPerSecond(snapshot?.network.downloadBytesPerSecond)
        let networkUpText = MetricFormatter.bytesPerSecond(snapshot?.network.uploadBytesPerSecond)

        switch mode {
        case .memory:
            return "RAM: \(memoryText)"
        case .storage:
            return "SSD: \(storageText)"
        case .cpu:
            return "CPU: \(cpuText)"
        case .network:
            return "NET: D \(networkDownText) U \(networkUpText)"
        case .both:
            return "RAM: \(memoryText) | SSD: \(storageText)"
        case .icon:
            return nil
        }
    }

    private static func metricText(
        usedBytes: UInt64?,
        totalBytes: UInt64?,
        format: MenuBarMetricDisplayFormat
    ) -> String {
        guard let usedBytes, let totalBytes else {
            return "--"
        }

        let normalizedUsedBytes = min(usedBytes, totalBytes)
        let freeBytes = totalBytes > normalizedUsedBytes ? totalBytes - normalizedUsedBytes : 0

        switch format {
        case .percentUsage:
            return MetricFormatter.percent(used: normalizedUsedBytes, total: totalBytes)
        case .numberUsage:
            return MetricFormatter.bytes(normalizedUsedBytes)
        case .numberLeft:
            return "\(MetricFormatter.bytes(freeBytes)) left"
        }
    }
}
