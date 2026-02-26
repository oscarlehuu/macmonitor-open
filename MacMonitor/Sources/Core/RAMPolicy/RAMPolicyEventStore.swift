import Foundation

enum RAMPolicyTriggerKind: String, Codable {
    case immediate
    case sustained
}

struct RAMPolicyEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let policyID: UUID
    let bundleID: String
    let displayName: String
    let observedBytes: UInt64
    let thresholdBytes: UInt64
    let triggerKind: RAMPolicyTriggerKind
    let action: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date,
        policyID: UUID,
        bundleID: String,
        displayName: String,
        observedBytes: UInt64,
        thresholdBytes: UInt64,
        triggerKind: RAMPolicyTriggerKind,
        action: String = "notify",
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.policyID = policyID
        self.bundleID = bundleID
        self.displayName = displayName
        self.observedBytes = observedBytes
        self.thresholdBytes = thresholdBytes
        self.triggerKind = triggerKind
        self.action = action
        self.message = message
    }
}

protocol RAMPolicyEventStoring {
    func append(_ event: RAMPolicyEvent) throws
    func recentEvents(limit: Int) -> [RAMPolicyEvent]
    func pruneExpiredEvents(referenceDate: Date)
}

final class FileRAMPolicyEventStore: RAMPolicyEventStoring {
    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.oscar.macmonitor.ram-policy-event-store")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let retentionInterval: TimeInterval

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        retentionDays: Int = 7
    ) {
        self.fileManager = fileManager
        let resolvedDirectory = FileRAMPolicyStore.resolveDirectoryURL(directoryURL: directoryURL, fileManager: fileManager)
        self.fileURL = resolvedDirectory.appendingPathComponent("ram-policy-events.jsonl", isDirectory: false)
        self.retentionInterval = TimeInterval(max(1, retentionDays) * 24 * 60 * 60)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func append(_ event: RAMPolicyEvent) throws {
        try syncThrowing {
            var events = loadEvents()
            events = prune(events: events, referenceDate: event.timestamp)
            events.append(event)
            try write(events: events)
        }
    }

    func recentEvents(limit: Int) -> [RAMPolicyEvent] {
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

    private func loadEvents() -> [RAMPolicyEvent] {
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
                return try? decoder.decode(RAMPolicyEvent.self, from: lineData)
            }
    }

    private func prune(events: [RAMPolicyEvent], referenceDate: Date) -> [RAMPolicyEvent] {
        events.filter { referenceDate.timeIntervalSince($0.timestamp) <= retentionInterval }
    }

    private func write(events: [RAMPolicyEvent]) throws {
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
