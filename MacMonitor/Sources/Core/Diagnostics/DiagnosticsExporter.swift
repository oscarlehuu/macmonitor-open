import Foundation

enum DiagnosticsExporterError: LocalizedError {
    case failedToCreateDirectory

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory:
            return "Unable to create diagnostics directory."
        }
    }
}

@MainActor
final class DiagnosticsExporter {
    private let fileManager: FileManager
    private let now: () -> Date
    private let outputBaseDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        outputBaseDirectoryURL: URL = FileManager.default.temporaryDirectory,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.outputBaseDirectoryURL = outputBaseDirectoryURL
        self.now = now
    }

    func exportDiagnosticsBundle(
        settings: SettingsStore,
        snapshot: SystemSnapshot?,
        history: [SystemSnapshot],
        recentBatteryEvents: [BatteryControlEvent],
        updateStatusMessage: String,
        helperAvailability: BatteryControlAvailability
    ) throws -> URL {
        let date = now()
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
        let directoryURL = outputBaseDirectoryURL.appendingPathComponent(
            "MacMonitor-Diagnostics-\(timestamp)",
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw DiagnosticsExporterError.failedToCreateDirectory
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        writeJSON(
            value: makeMetadata(now: date, updateStatusMessage: updateStatusMessage, helperAvailability: helperAvailability),
            named: "metadata.json",
            in: directoryURL,
            encoder: encoder
        )
        writeJSON(
            value: makeSettingsSnapshot(settings),
            named: "settings.json",
            in: directoryURL,
            encoder: encoder
        )
        writeJSON(
            value: makeSnapshotSummary(snapshot: snapshot, history: history),
            named: "snapshot-summary.json",
            in: directoryURL,
            encoder: encoder
        )
        writeJSON(
            value: makeBatteryEventsSnapshot(recentBatteryEvents),
            named: "battery-events.json",
            in: directoryURL,
            encoder: encoder
        )
        writeJSON(
            value: makeLifecycleSnapshot(from: recentBatteryEvents),
            named: "lifecycle-events.json",
            in: directoryURL,
            encoder: encoder
        )

        return directoryURL
    }

    private func writeJSON<Value: Encodable>(
        value: Value,
        named fileName: String,
        in directoryURL: URL,
        encoder: JSONEncoder
    ) {
        let fileURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func makeMetadata(
        now: Date,
        updateStatusMessage: String,
        helperAvailability: BatteryControlAvailability
    ) -> DiagnosticsMetadata {
        let helperAvailabilityText: String
        switch helperAvailability {
        case .available:
            helperAvailabilityText = "available"
        case .unavailable(let reason):
            helperAvailabilityText = "unavailable: \(sanitize(reason))"
        }

        return DiagnosticsMetadata(
            generatedAt: now,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            helperAvailability: helperAvailabilityText,
            updateStatus: sanitize(updateStatusMessage)
        )
    }

    private func makeSettingsSnapshot(_ settings: SettingsStore) -> DiagnosticsSettingsSnapshot {
        DiagnosticsSettingsSnapshot(
            refreshIntervalMinutes: settings.refreshInterval.rawValue,
            menuBarDisplayMode: settings.menuBarDisplayMode.rawValue,
            menuBarMemoryFormat: settings.menuBarMemoryFormat.rawValue,
            menuBarStorageFormat: settings.menuBarStorageFormat.rawValue,
            launchAtLoginEnabled: settings.launchAtLoginEnabled,
            batteryPolicyConfiguration: settings.batteryPolicyConfiguration,
            systemAlertSettings: settings.systemAlertSettings,
            batteryAdvancedControlFeatureFlags: settings.batteryAdvancedControlFeatureFlags
        )
    }

    private func makeSnapshotSummary(snapshot: SystemSnapshot?, history: [SystemSnapshot]) -> DiagnosticsSnapshotSummary {
        let recentHistory = Array(history.suffix(120))
        return DiagnosticsSnapshotSummary(
            latestSnapshot: snapshot,
            historyPointCount: history.count,
            recentHistory: recentHistory
        )
    }

    private func makeBatteryEventsSnapshot(_ events: [BatteryControlEvent]) -> DiagnosticsBatteryEvents {
        let eventPayloads = events.map { event in
            DiagnosticsBatteryEvent(
                timestamp: event.timestamp,
                source: event.source.rawValue,
                state: event.state.rawValue,
                command: event.command.map(String.init(describing:)),
                accepted: event.accepted,
                message: sanitize(event.message),
                batteryPercent: event.batteryPercent
            )
        }
        return DiagnosticsBatteryEvents(events: eventPayloads)
    }

    private func makeLifecycleSnapshot(from events: [BatteryControlEvent]) -> DiagnosticsLifecycleEvents {
        let lifecycleEvents = events
            .filter { $0.source == .lifecycle }
            .map { event in
                DiagnosticsLifecycleEvent(
                    timestamp: event.timestamp,
                    state: event.state.rawValue,
                    accepted: event.accepted,
                    message: sanitize(event.message)
                )
            }
        return DiagnosticsLifecycleEvents(events: lifecycleEvents)
    }

    private func sanitize(_ value: String) -> String {
        var sanitized = value
        sanitized = sanitized.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        sanitized = redactingUserPath(in: sanitized)
        return sanitized
    }

    private func redactingUserPath(in value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "/Users/[^/]+", options: []) else {
            return value
        }
        let range = NSRange(value.startIndex..., in: value)
        return regex.stringByReplacingMatches(
            in: value,
            options: [],
            range: range,
            withTemplate: "/Users/<redacted>"
        )
    }
}

private struct DiagnosticsMetadata: Codable {
    let generatedAt: Date
    let appVersion: String
    let appBuild: String
    let osVersion: String
    let helperAvailability: String
    let updateStatus: String
}

private struct DiagnosticsSettingsSnapshot: Codable {
    let refreshIntervalMinutes: Int
    let menuBarDisplayMode: String
    let menuBarMemoryFormat: String
    let menuBarStorageFormat: String
    let launchAtLoginEnabled: Bool
    let batteryPolicyConfiguration: BatteryPolicyConfiguration
    let systemAlertSettings: SystemAlertSettings
    let batteryAdvancedControlFeatureFlags: BatteryAdvancedControlFeatureFlags
}

private struct DiagnosticsSnapshotSummary: Codable {
    let latestSnapshot: SystemSnapshot?
    let historyPointCount: Int
    let recentHistory: [SystemSnapshot]
}

private struct DiagnosticsBatteryEvents: Codable {
    let events: [DiagnosticsBatteryEvent]
}

private struct DiagnosticsBatteryEvent: Codable {
    let timestamp: Date
    let source: String
    let state: String
    let command: String?
    let accepted: Bool
    let message: String
    let batteryPercent: Int?
}

private struct DiagnosticsLifecycleEvents: Codable {
    let events: [DiagnosticsLifecycleEvent]
}

private struct DiagnosticsLifecycleEvent: Codable {
    let timestamp: Date
    let state: String
    let accepted: Bool
    let message: String
}
