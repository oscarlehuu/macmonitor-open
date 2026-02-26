import Foundation

protocol RAMPolicyStoring {
    func loadPolicies() -> [RAMPolicy]
    func savePolicy(_ policy: RAMPolicy) throws
    func deletePolicy(id: UUID) throws
}

final class FileRAMPolicyStore: RAMPolicyStoring {
    private struct Payload: Codable {
        let version: Int
        var policies: [RAMPolicy]

        init(version: Int = 1, policies: [RAMPolicy]) {
            self.version = version
            self.policies = policies
        }
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.oscar.macmonitor.ram-policy-store")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let resolvedDirectory = Self.resolveDirectoryURL(directoryURL: directoryURL, fileManager: fileManager)
        self.fileURL = resolvedDirectory.appendingPathComponent("ram-policies.json", isDirectory: false)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadPolicies() -> [RAMPolicy] {
        queue.sync {
            loadPayload().policies
                .map(\.normalized)
                .sorted { lhs, rhs in
                    lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
        }
    }

    func savePolicy(_ policy: RAMPolicy) throws {
        try syncThrowing {
            var payload = loadPayload()
            let normalized = policy.normalized

            if let index = payload.policies.firstIndex(where: { $0.id == normalized.id }) {
                payload.policies[index] = normalized
            } else {
                payload.policies.append(normalized)
            }

            try savePayload(payload)
        }
    }

    func deletePolicy(id: UUID) throws {
        try syncThrowing {
            var payload = loadPayload()
            payload.policies.removeAll { $0.id == id }
            try savePayload(payload)
        }
    }

    static func resolveDirectoryURL(directoryURL: URL?, fileManager: FileManager) -> URL {
        if let directoryURL {
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            return directoryURL
        }

        if let directory = try? AppDataDirectory.url(fileManager: fileManager) {
            return directory
        }

        let fallbackDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("com.oscar.macmonitor-fallback", isDirectory: true)
        if !fileManager.fileExists(atPath: fallbackDirectory.path) {
            try? fileManager.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
        }
        return fallbackDirectory
    }

    private func loadPayload() -> Payload {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return Payload(policies: [])
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return Payload(policies: [])
        }

        if let decoded = try? decoder.decode(Payload.self, from: data) {
            return decoded
        }

        archiveCorruptFileIfPossible()
        return Payload(policies: [])
    }

    private func savePayload(_ payload: Payload) throws {
        let sortedPayload = Payload(
            version: payload.version,
            policies: payload.policies
                .map(\.normalized)
                .sorted { lhs, rhs in
                    lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
        )

        let data = try encoder.encode(sortedPayload)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func archiveCorruptFileIfPossible() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let suffix = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let archivedURL = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(suffix).json")
        try? fileManager.moveItem(at: fileURL, to: archivedURL)
    }

    private func syncThrowing<T>(_ work: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        queue.sync {
            result = Result { try work() }
        }
        return try result.get()
    }
}
