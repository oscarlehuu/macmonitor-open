import Foundation

enum AppDataDirectory {
    private static let folderName = "com.oscar.macmonitor"

    static func url(fileManager: FileManager = .default) throws -> URL {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppDataDirectoryError.applicationSupportUnavailable
        }

        let directoryURL = applicationSupportURL.appendingPathComponent(folderName, isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
    }
}

enum AppDataDirectoryError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "Unable to locate Application Support directory."
        }
    }
}
