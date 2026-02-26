import Foundation

final class SnapshotStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let legacyFileURL: URL
    private let maxHistoryCount: Int
    private let trimIntervalAppends: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.oscar.macmonitor.snapshot-store")
    private var appendCountSinceTrim = 0

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        maxHistoryCount: Int = 3_500,
        trimIntervalAppends: Int = 24
    ) {
        self.fileManager = fileManager
        self.maxHistoryCount = max(1, maxHistoryCount)
        self.trimIntervalAppends = max(1, trimIntervalAppends)

        let directory: URL
        if let baseDirectoryURL {
            directory = baseDirectoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            directory = appSupport.appendingPathComponent("MacMonitor", isDirectory: true)
        }

        self.fileURL = directory.appendingPathComponent("snapshots.jsonl")
        self.legacyFileURL = directory.appendingPathComponent("snapshots.json")

        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        decoder.dateDecodingStrategy = .deferredToDate

        ensureStorageDirectoryExists()
    }

    func loadHistory() -> [SystemSnapshot] {
        queue.sync {
            if fileManager.fileExists(atPath: fileURL.path) {
                return loadJSONL(at: fileURL)
            }

            // One-time migration from legacy JSON array format.
            guard fileManager.fileExists(atPath: legacyFileURL.path),
                  let data = try? Data(contentsOf: legacyFileURL),
                  let snapshots = try? decoder.decode([SystemSnapshot].self, from: data) else {
                return []
            }

            let trimmed = Array(snapshots.suffix(maxHistoryCount))
            if writeJSONL(trimmed, to: fileURL) {
                try? fileManager.removeItem(at: legacyFileURL)
            }
            return trimmed
        }
    }

    func append(_ snapshot: SystemSnapshot) {
        queue.sync {
            ensureStorageDirectoryExists()

            guard let encoded = try? encoder.encode(snapshot),
                  var line = String(data: encoded, encoding: .utf8) else {
                return
            }
            line.append("\n")
            guard let payload = line.data(using: .utf8) else { return }

            if !fileManager.fileExists(atPath: fileURL.path) {
                try? payload.write(to: fileURL, options: .atomic)
            } else if let handle = try? FileHandle(forWritingTo: fileURL) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: payload)
                    try handle.close()
                } catch {
                    try? handle.close()
                }
            }

            appendCountSinceTrim += 1
            if maxHistoryCount <= 256 || appendCountSinceTrim >= trimIntervalAppends {
                appendCountSinceTrim = 0
                trimHistoryIfNeeded()
            }
        }
    }

    func save(_ history: [SystemSnapshot]) {
        queue.sync {
            ensureStorageDirectoryExists()
            let trimmed = Array(history.suffix(maxHistoryCount))
            writeJSONL(trimmed, to: fileURL)
        }
    }

    private func ensureStorageDirectoryExists() {
        let directory = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func trimHistoryIfNeeded() {
        let history = loadJSONL(at: fileURL)
        guard history.count > maxHistoryCount else { return }
        writeJSONL(Array(history.suffix(maxHistoryCount)), to: fileURL)
    }

    private func loadJSONL(at url: URL) -> [SystemSnapshot] {
        guard let payload = try? String(contentsOf: url, encoding: .utf8), !payload.isEmpty else {
            return []
        }

        return payload
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(SystemSnapshot.self, from: data)
            }
    }

    @discardableResult
    private func writeJSONL(_ snapshots: [SystemSnapshot], to url: URL) -> Bool {
        guard !snapshots.isEmpty else {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    return false
                }
            }
            return true
        }

        let lines = snapshots.compactMap { snapshot -> String? in
            guard let data = try? encoder.encode(snapshot) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        let payload = lines.joined(separator: "\n") + "\n"
        do {
            try payload.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
