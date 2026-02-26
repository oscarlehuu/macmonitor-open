import Foundation

enum StorageManagedItemCategory: String, CaseIterable, Equatable, Sendable {
    case application
    case cache
    case folder

    var title: String {
        switch self {
        case .application:
            return "App"
        case .cache:
            return "Cache"
        case .folder:
            return "Folder"
        }
    }

    var symbolName: String {
        switch self {
        case .application:
            return "app.dashed"
        case .cache:
            return "externaldrive.badge.timemachine"
        case .folder:
            return "folder"
        }
    }
}

enum StorageManagedItemKind: String, Equatable, Sendable {
    case appBundle
    case appCache
    case appSupport
    case appContainer
    case appLogs
    case appPreferences
    case looseCache
    case looseFolder
    case derivedData
    case xcodeArchives
    case simulatorData
    case nodeModules
    case npmCache
    case yarnCache
    case pnpmStore
    case customFolder
    case drillDown

    var title: String {
        switch self {
        case .appBundle:
            return "App Bundle"
        case .appCache:
            return "App Cache"
        case .appSupport:
            return "App Support"
        case .appContainer:
            return "Sandbox"
        case .appLogs:
            return "Logs"
        case .appPreferences:
            return "Preferences"
        case .looseCache:
            return "Cache"
        case .looseFolder:
            return "Folder"
        case .derivedData:
            return "DerivedData"
        case .xcodeArchives:
            return "Archives"
        case .simulatorData:
            return "Simulator"
        case .nodeModules:
            return "node_modules"
        case .npmCache:
            return "npm"
        case .yarnCache:
            return "Yarn"
        case .pnpmStore:
            return "pnpm"
        case .customFolder:
            return "Custom"
        case .drillDown:
            return "Child"
        }
    }
}

enum StorageCleanupPreset: String, CaseIterable, Equatable, Sendable, Identifiable {
    case browsers
    case xcode
    case node
    case caches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browsers:
            return "Browsers"
        case .xcode:
            return "Xcode"
        case .node:
            return "Node"
        case .caches:
            return "Caches"
        }
    }

    var subtitle: String {
        switch self {
        case .browsers:
            return "Browser app + data"
        case .xcode:
            return "DerivedData, archives, simulator"
        case .node:
            return "node_modules and package caches"
        case .caches:
            return "All cache folders"
        }
    }
}

enum StorageSelectionState: Equatable {
    case none
    case partial
    case all
}

enum StorageProtectionReason: String, Equatable, Sendable {
    case protectedRoot
    case systemPath
    case currentApplication

    var description: String {
        switch self {
        case .protectedRoot:
            return "Protected root"
        case .systemPath:
            return "System path"
        case .currentApplication:
            return "Current app"
        }
    }
}

struct StorageProtectionDecision: Equatable, Sendable {
    let isProtected: Bool
    let reason: StorageProtectionReason?

    static let allow = StorageProtectionDecision(isProtected: false, reason: nil)

    static func deny(_ reason: StorageProtectionReason) -> StorageProtectionDecision {
        StorageProtectionDecision(isProtected: true, reason: reason)
    }
}

struct StorageManagedItem: Identifiable, Equatable, Sendable {
    let url: URL
    let displayName: String
    let category: StorageManagedItemCategory
    let kind: StorageManagedItemKind
    let sizeBytes: UInt64
    let protectionReason: StorageProtectionReason?
    let isDirectory: Bool
    let parentID: String?
    let bundleIdentifier: String?
    let appGroupID: String?

    var id: String {
        url.standardizedFileURL.path
    }

    var isProtected: Bool {
        protectionReason != nil
    }

    var isExpandable: Bool {
        isDirectory
    }
}

struct StorageAppGroup: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let bundleIdentifier: String?
    let items: [StorageManagedItem]

    var totalBytes: UInt64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }
}

struct StorageDiskUsage: Equatable, Sendable {
    let usedBytes: UInt64
    let totalBytes: UInt64
}

struct StorageScanResult: Equatable, Sendable {
    let diskUsage: StorageDiskUsage?
    let appGroups: [StorageAppGroup]
    let looseItems: [StorageManagedItem]
}

enum StorageDeletionOutcome: Equatable, Sendable {
    case deleted
    case skippedProtected(StorageProtectionReason)
    case skippedStillRunning
    case skippedForceDeclined
    case permissionDenied
    case notFound
    case failed(code: Int32)
}

struct StorageDeletionResult: Equatable, Sendable {
    let id: String
    let displayName: String
    let outcome: StorageDeletionOutcome

    var isDeleted: Bool {
        if case .deleted = outcome {
            return true
        }
        return false
    }

    var isSkipped: Bool {
        switch outcome {
        case .skippedProtected, .skippedStillRunning, .skippedForceDeclined:
            return true
        case .deleted, .permissionDenied, .notFound, .failed:
            return false
        }
    }
}

struct StorageDeletionSummary: Equatable, Sendable {
    let results: [StorageDeletionResult]

    var deletedCount: Int {
        results.filter(\.isDeleted).count
    }

    var skippedCount: Int {
        results.filter(\.isSkipped).count
    }

    var failedCount: Int {
        results.count - deletedCount - skippedCount
    }

    var skippedStillRunningCount: Int {
        results.filter { result in
            if case .skippedStillRunning = result.outcome {
                return true
            }
            return false
        }.count
    }

    var skippedForceDeclinedCount: Int {
        results.filter { result in
            if case .skippedForceDeclined = result.outcome {
                return true
            }
            return false
        }.count
    }

    var message: String {
        var components = ["Deleted \(deletedCount), skipped \(skippedCount), failed \(failedCount)."]
        if skippedStillRunningCount > 0 {
            components.append("Still running: \(skippedStillRunningCount).")
        }
        if skippedForceDeclinedCount > 0 {
            components.append("Force declined: \(skippedForceDeclinedCount).")
        }
        return components.joined(separator: " ")
    }
}

protocol StorageManaging: Sendable {
    func scan(customFolders: [URL]) -> StorageScanResult
    func drillDown(item: StorageManagedItem, limit: Int) -> [StorageManagedItem]
    func delete(items: [StorageManagedItem], selectedItemIDs: Set<String>) -> StorageDeletionSummary
}
