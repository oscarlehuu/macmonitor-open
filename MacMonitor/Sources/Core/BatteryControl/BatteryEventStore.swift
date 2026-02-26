import Foundation

enum BatteryControlEventSource: String, Codable {
    case policy
    case manual
    case lifecycle
    case schedule
    case shortcut
    case system
}

struct BatteryControlEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let source: BatteryControlEventSource
    let state: BatteryControlState
    let command: BatteryControlCommand?
    let accepted: Bool
    let message: String
    let batteryPercent: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        source: BatteryControlEventSource,
        state: BatteryControlState,
        command: BatteryControlCommand?,
        accepted: Bool,
        message: String,
        batteryPercent: Int?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.state = state
        self.command = command
        self.accepted = accepted
        self.message = message
        self.batteryPercent = batteryPercent
    }
}

protocol BatteryEventStoring {
    func append(_ event: BatteryControlEvent) throws
    func recentEvents(limit: Int) -> [BatteryControlEvent]
    func pruneExpiredEvents(referenceDate: Date)
}

final class FileBatteryEventStore: BatteryEventStoring {
    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.oscar.macmonitor.battery-event-store")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let retentionInterval: TimeInterval

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        retentionDays: Int = 14
    ) {
        self.fileManager = fileManager
        let resolvedDirectory = FileRAMPolicyStore.resolveDirectoryURL(directoryURL: directoryURL, fileManager: fileManager)
        self.fileURL = resolvedDirectory.appendingPathComponent("battery-events.jsonl", isDirectory: false)
        self.retentionInterval = TimeInterval(max(1, retentionDays) * 24 * 60 * 60)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func append(_ event: BatteryControlEvent) throws {
        try syncThrowing {
            var events = loadEvents()
            events = prune(events: events, referenceDate: event.timestamp)
            events.append(event)
            try write(events: events)
        }
    }

    func recentEvents(limit: Int) -> [BatteryControlEvent] {
        queue.sync {
            guard limit > 0 else { return [] }
            let pruned = prune(events: loadEvents(), referenceDate: Date())
            return Array(
                pruned
                    .sorted(by: { $0.timestamp > $1.timestamp })
                    .prefix(limit)
            )
        }
    }

    func pruneExpiredEvents(referenceDate: Date = Date()) {
        queue.sync {
            let events = prune(events: loadEvents(), referenceDate: referenceDate)
            try? write(events: events)
        }
    }

    private func loadEvents() -> [BatteryControlEvent] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        guard let data = try? Data(contentsOf: fileURL),
              let payload = String(data: data, encoding: .utf8) else {
            return []
        }

        return payload
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                guard let lineData = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(BatteryControlEvent.self, from: lineData)
            }
    }

    private func prune(events: [BatteryControlEvent], referenceDate: Date) -> [BatteryControlEvent] {
        events.filter { referenceDate.timeIntervalSince($0.timestamp) <= retentionInterval }
    }

    private func write(events: [BatteryControlEvent]) throws {
        if events.isEmpty {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            return
        }

        let lines = try events.map { event -> String in
            let data = try encoder.encode(event)
            return String(decoding: data, as: UTF8.self)
        }

        let content = lines.joined(separator: "\n") + "\n"
        guard let data = content.data(using: .utf8) else {
            return
        }

        try data.write(to: fileURL, options: [.atomic])
    }

    private func syncThrowing<T>(_ work: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        queue.sync {
            result = Result { try work() }
        }
        return try result.get()
    }
}
