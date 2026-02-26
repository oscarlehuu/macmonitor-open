import Foundation

protocol BatteryScheduleStoring {
    func loadTasks() -> [BatteryScheduledTask]
    func saveTasks(_ tasks: [BatteryScheduledTask]) throws
}

final class FileBatteryScheduleStore: BatteryScheduleStoring {
    private struct Payload: Codable {
        let version: Int
        let tasks: [BatteryScheduledTask]

        init(version: Int = 1, tasks: [BatteryScheduledTask]) {
            self.version = version
            self.tasks = tasks
        }
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.oscar.macmonitor.battery-schedule-store")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let resolvedDirectory = FileRAMPolicyStore.resolveDirectoryURL(directoryURL: directoryURL, fileManager: fileManager)
        self.fileURL = resolvedDirectory.appendingPathComponent("battery-schedule.json", isDirectory: false)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadTasks() -> [BatteryScheduledTask] {
        queue.sync {
            guard fileManager.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL),
                  let payload = try? decoder.decode(Payload.self, from: data) else {
                return []
            }

            return payload.tasks.sorted(by: { lhs, rhs in
                if lhs.scheduledAt == rhs.scheduledAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.scheduledAt < rhs.scheduledAt
            })
        }
    }

    func saveTasks(_ tasks: [BatteryScheduledTask]) throws {
        try syncThrowing {
            let payload = Payload(tasks: tasks)
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: [.atomic])
        }
    }

    private func syncThrowing<T>(_ work: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        queue.sync {
            result = Result { try work() }
        }
        return try result.get()
    }
}
