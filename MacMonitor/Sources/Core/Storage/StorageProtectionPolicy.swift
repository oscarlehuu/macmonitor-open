import Foundation

protocol StorageProtecting: Sendable {
    func evaluate(url: URL) -> StorageProtectionDecision
}

struct DefaultStorageProtectionPolicy: StorageProtecting {
    private let currentApplicationPath: String
    private let protectedRootPaths: Set<String>
    private let protectedPathPrefixes: [String]

    init(
        currentApplicationPath: String = Bundle.main.bundleURL.standardizedFileURL.path,
        protectedRootPaths: Set<String> = ["/", "/System", "/usr", "/bin", "/sbin", "/private"],
        protectedPathPrefixes: [String] = ["/System/", "/usr/", "/bin/", "/sbin/", "/private/"]
    ) {
        self.currentApplicationPath = currentApplicationPath
        self.protectedRootPaths = protectedRootPaths
        self.protectedPathPrefixes = protectedPathPrefixes
    }

    func evaluate(url: URL) -> StorageProtectionDecision {
        let normalizedPath = url.standardizedFileURL.path

        if normalizedPath == currentApplicationPath || normalizedPath.hasPrefix(currentApplicationPath + "/") {
            return .deny(.currentApplication)
        }

        if protectedRootPaths.contains(normalizedPath) {
            return .deny(.protectedRoot)
        }

        if protectedPathPrefixes.contains(where: { normalizedPath.hasPrefix($0) }) {
            return .deny(.systemPath)
        }

        return .allow
    }
}
