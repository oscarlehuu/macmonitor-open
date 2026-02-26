import Foundation

protocol StorageCollecting {
    func collect() -> StorageSnapshot?
}

struct StorageCollector: StorageCollecting {
    private let fileManager: FileManager
    private let path: String

    init(fileManager: FileManager = .default, path: String = "/") {
        self.fileManager = fileManager
        self.path = path
    }

    func collect() -> StorageSnapshot? {
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: path),
              let total = (attributes[.systemSize] as? NSNumber)?.uint64Value,
              let free = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value else {
            return nil
        }

        let used = total > free ? (total - free) : 0
        return StorageSnapshot(usedBytes: used, totalBytes: total)
    }
}
