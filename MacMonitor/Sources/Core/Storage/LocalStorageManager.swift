import Darwin
import Foundation

struct LocalStorageManager: StorageManaging {
    private struct AppBundleInfo {
        let groupID: String
        let displayName: String
        let bundleIdentifier: String?
        let item: StorageManagedItem
    }

    private let protectionPolicy: StorageProtecting
    private static let scanCacheLock = NSLock()
    private static let scanCacheTTL: TimeInterval = 30
    nonisolated(unsafe) private static var cachedScanFingerprint: String?
    nonisolated(unsafe) private static var cachedScanResult: StorageScanResult?
    nonisolated(unsafe) private static var cachedScanTimestamp: Date?

    init(protectionPolicy: StorageProtecting = DefaultStorageProtectionPolicy()) {
        self.protectionPolicy = protectionPolicy
    }

    func scan(customFolders: [URL]) -> StorageScanResult {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let fingerprint = scanFingerprint(
            customFolders: customFolders,
            homeDirectory: homeDirectory,
            fileManager: fileManager
        )

        if let cachedResult = cachedResult(for: fingerprint) {
            return cachedResult
        }

        let diskUsage = collectDiskUsage(fileManager: fileManager)

        let appInfos = collectAppBundleInfos(fileManager: fileManager)
        let knownBundleIdentifiers = Set(appInfos.compactMap(\.bundleIdentifier))

        var matchedAppRelatedPaths = Set<String>()
        var appGroups: [StorageAppGroup] = []
        appGroups.reserveCapacity(appInfos.count)

        for appInfo in appInfos {
            var items: [StorageManagedItem] = [appInfo.item]
            let appRelatedItems = collectAppRelatedItems(
                for: appInfo,
                homeDirectory: homeDirectory,
                fileManager: fileManager
            )
            for item in appRelatedItems {
                matchedAppRelatedPaths.insert(item.id)
                items.append(item)
            }

            items = deduplicate(items)
            items.sort(by: sortDescendingBySizeThenName)

            appGroups.append(
                StorageAppGroup(
                    id: appInfo.groupID,
                    displayName: appInfo.displayName,
                    bundleIdentifier: appInfo.bundleIdentifier,
                    items: items
                )
            )
        }

        appGroups.sort { lhs, rhs in
            if lhs.totalBytes == rhs.totalBytes {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.totalBytes > rhs.totalBytes
        }

        let looseItems = collectLooseItems(
            customFolders: customFolders,
            excludedPaths: matchedAppRelatedPaths,
            knownBundleIdentifiers: knownBundleIdentifiers,
            homeDirectory: homeDirectory,
            fileManager: fileManager
        )

        let result = StorageScanResult(
            diskUsage: diskUsage,
            appGroups: appGroups,
            looseItems: looseItems
        )

        storeCachedResult(result, for: fingerprint)
        return result
    }

    func drillDown(item: StorageManagedItem, limit: Int) -> [StorageManagedItem] {
        guard item.isDirectory else { return [] }

        let fileManager = FileManager.default
        guard let childURLs = try? fileManager.contentsOfDirectory(
            at: item.url,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let children = childURLs.compactMap { childURL -> StorageManagedItem? in
            let category = guessCategory(for: childURL)
            return makeItem(
                url: childURL,
                category: category,
                kind: .drillDown,
                parentID: item.id,
                bundleIdentifier: item.bundleIdentifier,
                appGroupID: item.appGroupID,
                displayName: nil,
                fileManager: fileManager
            )
        }

        return Array(
            children
                .sorted(by: sortDescendingBySizeThenName)
                .prefix(max(limit, 0))
        )
    }

    func delete(items: [StorageManagedItem], selectedItemIDs: Set<String>) -> StorageDeletionSummary {
        let fileManager = FileManager.default
        let selected = items.filter { selectedItemIDs.contains($0.id) }
        let targets = normalizeDeletionTargets(selected)

        var results: [StorageDeletionResult] = []
        results.reserveCapacity(targets.count)

        for item in targets {
            let decision = protectionPolicy.evaluate(url: item.url)
            if let reason = decision.reason {
                results.append(
                    StorageDeletionResult(
                        id: item.id,
                        displayName: item.displayName,
                        outcome: .skippedProtected(reason)
                    )
                )
                continue
            }

            do {
                var trashedItemURL: NSURL?
                try fileManager.trashItem(at: item.url, resultingItemURL: &trashedItemURL)
                results.append(
                    StorageDeletionResult(
                        id: item.id,
                        displayName: item.displayName,
                        outcome: .deleted
                    )
                )
            } catch {
                results.append(
                    StorageDeletionResult(
                        id: item.id,
                        displayName: item.displayName,
                        outcome: mapDeletionError(error)
                    )
                )
            }
        }

        let summary = StorageDeletionSummary(results: results)
        if summary.deletedCount > 0 {
            invalidateCachedResult()
        }
        return summary
    }

    private func collectDiskUsage(fileManager: FileManager) -> StorageDiskUsage? {
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: "/") else {
            return nil
        }

        let totalBytes = numberValue(from: attributes[.systemSize])
        let freeBytes = numberValue(from: attributes[.systemFreeSize])

        guard totalBytes > 0 else { return nil }
        let usedBytes = totalBytes > freeBytes ? totalBytes - freeBytes : 0
        return StorageDiskUsage(usedBytes: usedBytes, totalBytes: totalBytes)
    }

    private func collectAppBundleInfos(fileManager: FileManager) -> [AppBundleInfo] {
        let appRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var grouped: [String: AppBundleInfo] = [:]

        for root in appRoots {
            guard let children = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for child in children where child.pathExtension.lowercased() == "app" {
                let bundleIdentifier = Bundle(url: child)?.bundleIdentifier
                let groupID = bundleIdentifier ?? child.standardizedFileURL.path
                let displayName = child.deletingPathExtension().lastPathComponent

                guard let item = makeItem(
                    url: child,
                    category: .application,
                    kind: .appBundle,
                    parentID: nil,
                    bundleIdentifier: bundleIdentifier,
                    appGroupID: groupID,
                    displayName: displayName,
                    fileManager: fileManager
                ) else {
                    continue
                }

                if let existing = grouped[groupID], existing.item.sizeBytes >= item.sizeBytes {
                    continue
                }

                grouped[groupID] = AppBundleInfo(
                    groupID: groupID,
                    displayName: displayName,
                    bundleIdentifier: bundleIdentifier,
                    item: item
                )
            }
        }

        return grouped.values.sorted { lhs, rhs in
            if lhs.item.sizeBytes == rhs.item.sizeBytes {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.item.sizeBytes > rhs.item.sizeBytes
        }
    }

    private func collectAppRelatedItems(
        for appInfo: AppBundleInfo,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [StorageManagedItem] {
        guard let bundleIdentifier = appInfo.bundleIdentifier else {
            return []
        }

        let appName = appInfo.displayName
        let preferencesFile = homeDirectory
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).plist", isDirectory: false)

        let candidates: [(url: URL, category: StorageManagedItemCategory, kind: StorageManagedItemKind, isDirectory: Bool)] = [
            (
                homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true).appendingPathComponent(bundleIdentifier, isDirectory: true),
                .cache,
                .appCache,
                true
            ),
            (
                URL(fileURLWithPath: "/Library/Caches", isDirectory: true).appendingPathComponent(bundleIdentifier, isDirectory: true),
                .cache,
                .appCache,
                true
            ),
            (
                homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true).appendingPathComponent(bundleIdentifier, isDirectory: true),
                .folder,
                .appSupport,
                true
            ),
            (
                homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true).appendingPathComponent(appName, isDirectory: true),
                .folder,
                .appSupport,
                true
            ),
            (
                homeDirectory.appendingPathComponent("Library/Containers", isDirectory: true).appendingPathComponent(bundleIdentifier, isDirectory: true),
                .folder,
                .appContainer,
                true
            ),
            (
                homeDirectory.appendingPathComponent("Library/Logs", isDirectory: true).appendingPathComponent(bundleIdentifier, isDirectory: true),
                .cache,
                .appLogs,
                true
            ),
            (
                preferencesFile,
                .folder,
                .appPreferences,
                false
            )
        ]

        var items: [StorageManagedItem] = []
        for candidate in candidates {
            guard fileManager.fileExists(atPath: candidate.url.path) else { continue }
            guard candidate.url.standardizedFileURL.path != appInfo.item.id else { continue }

            let displayName: String?
            switch candidate.kind {
            case .appCache:
                displayName = "Cache"
            case .appSupport:
                displayName = "Application Support"
            case .appContainer:
                displayName = "Containers"
            case .appLogs:
                displayName = "Logs"
            case .appPreferences:
                displayName = "Preferences"
            default:
                displayName = nil
            }

            guard let item = makeItem(
                url: candidate.url,
                category: candidate.category,
                kind: candidate.kind,
                parentID: nil,
                bundleIdentifier: bundleIdentifier,
                appGroupID: appInfo.groupID,
                displayName: displayName,
                fileManager: fileManager
            ) else {
                continue
            }
            items.append(item)
        }

        return items
    }

    private func collectLooseItems(
        customFolders: [URL],
        excludedPaths: Set<String>,
        knownBundleIdentifiers: Set<String>,
        homeDirectory: URL,
        fileManager: FileManager
    ) -> [StorageManagedItem] {
        var looseItems: [StorageManagedItem] = []

        let cacheRoots = [
            homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true),
            URL(fileURLWithPath: "/Library/Caches", isDirectory: true)
        ]

        for cacheRoot in cacheRoots {
            guard let childURLs = try? fileManager.contentsOfDirectory(
                at: cacheRoot,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for childURL in childURLs {
                let normalizedPath = childURL.standardizedFileURL.path
                if excludedPaths.contains(normalizedPath) {
                    continue
                }
                if knownBundleIdentifiers.contains(childURL.lastPathComponent) {
                    continue
                }

                guard let item = makeItem(
                    url: childURL,
                    category: .cache,
                    kind: .looseCache,
                    parentID: nil,
                    bundleIdentifier: nil,
                    appGroupID: nil,
                    displayName: nil,
                    fileManager: fileManager
                ) else {
                    continue
                }

                looseItems.append(item)
            }
        }

        let xcodeTargets: [(URL, StorageManagedItemKind)] = [
            (homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true), .derivedData),
            (homeDirectory.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true), .xcodeArchives),
            (homeDirectory.appendingPathComponent("Library/Developer/CoreSimulator", isDirectory: true), .simulatorData)
        ]

        for (targetURL, kind) in xcodeTargets where fileManager.fileExists(atPath: targetURL.path) {
            if let item = makeItem(
                url: targetURL,
                category: .folder,
                kind: kind,
                parentID: nil,
                bundleIdentifier: nil,
                appGroupID: nil,
                displayName: nil,
                fileManager: fileManager
            ) {
                looseItems.append(item)
            }
        }

        let nodeTargets: [(URL, StorageManagedItemKind, StorageManagedItemCategory)] = [
            (homeDirectory.appendingPathComponent(".npm", isDirectory: true), .npmCache, .cache),
            (homeDirectory.appendingPathComponent(".pnpm-store", isDirectory: true), .pnpmStore, .cache),
            (homeDirectory.appendingPathComponent(".cache/yarn", isDirectory: true), .yarnCache, .cache),
            (homeDirectory.appendingPathComponent("Library/Caches/Yarn", isDirectory: true), .yarnCache, .cache),
            (homeDirectory.appendingPathComponent("Library/Caches/pnpm", isDirectory: true), .pnpmStore, .cache)
        ]

        for (targetURL, kind, category) in nodeTargets where fileManager.fileExists(atPath: targetURL.path) {
            if let item = makeItem(
                url: targetURL,
                category: category,
                kind: kind,
                parentID: nil,
                bundleIdentifier: nil,
                appGroupID: nil,
                displayName: nil,
                fileManager: fileManager
            ) {
                looseItems.append(item)
            }
        }

        let nodeModuleURLs = collectNodeModuleFolders(homeDirectory: homeDirectory, fileManager: fileManager, maxCount: 80)
        for nodeModuleURL in nodeModuleURLs {
            if let item = makeItem(
                url: nodeModuleURL,
                category: .folder,
                kind: .nodeModules,
                parentID: nil,
                bundleIdentifier: nil,
                appGroupID: nil,
                displayName: nil,
                fileManager: fileManager
            ) {
                looseItems.append(item)
            }
        }

        for customFolder in customFolders {
            if let item = makeItem(
                url: customFolder,
                category: .folder,
                kind: .customFolder,
                parentID: nil,
                bundleIdentifier: nil,
                appGroupID: nil,
                displayName: nil,
                fileManager: fileManager
            ) {
                looseItems.append(item)
            }
        }

        return deduplicate(looseItems).sorted(by: sortDescendingBySizeThenName)
    }

    private func collectNodeModuleFolders(
        homeDirectory: URL,
        fileManager: FileManager,
        maxCount: Int
    ) -> [URL] {
        let searchRoots = [
            homeDirectory.appendingPathComponent("Developer", isDirectory: true),
            homeDirectory.appendingPathComponent("Projects", isDirectory: true)
        ]

        var found: [URL] = []
        found.reserveCapacity(maxCount)

        for root in searchRoots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            let rootDepth = root.pathComponents.count
            for case let url as URL in enumerator {
                if found.count >= maxCount {
                    return found
                }

                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
                    continue
                }
                guard values.isDirectory == true else {
                    continue
                }

                let depth = url.pathComponents.count - rootDepth
                if depth > 5 {
                    enumerator.skipDescendants()
                    continue
                }

                if url.lastPathComponent.lowercased() == "node_modules" {
                    found.append(url.standardizedFileURL)
                    enumerator.skipDescendants()
                }
            }
        }

        return found
    }

    private func guessCategory(for url: URL) -> StorageManagedItemCategory {
        if url.pathExtension.lowercased() == "app" {
            return .application
        }

        let normalizedPath = url.path.lowercased()
        if normalizedPath.contains("/cache") || normalizedPath.contains("caches") {
            return .cache
        }

        return .folder
    }

    private func makeItem(
        url: URL,
        category: StorageManagedItemCategory,
        kind: StorageManagedItemKind,
        parentID: String?,
        bundleIdentifier: String?,
        appGroupID: String?,
        displayName: String?,
        fileManager: FileManager
    ) -> StorageManagedItem? {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.isFileURL else { return nil }
        guard fileManager.fileExists(atPath: standardizedURL.path) else { return nil }

        let resourceValues = try? standardizedURL.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = resourceValues?.isDirectory ?? false

        let protectionDecision = protectionPolicy.evaluate(url: standardizedURL)
        let sizeBytes = sizeForItem(at: standardizedURL, fileManager: fileManager)
        let resolvedName = displayName ?? {
            let rawName = standardizedURL.lastPathComponent
            guard !rawName.isEmpty else { return standardizedURL.path }
            if rawName.hasSuffix(".app") {
                return standardizedURL.deletingPathExtension().lastPathComponent
            }
            return rawName
        }()

        return StorageManagedItem(
            url: standardizedURL,
            displayName: resolvedName,
            category: category,
            kind: kind,
            sizeBytes: sizeBytes,
            protectionReason: protectionDecision.reason,
            isDirectory: isDirectory,
            parentID: parentID,
            bundleIdentifier: bundleIdentifier,
            appGroupID: appGroupID
        )
    }

    private func normalizeDeletionTargets(_ targets: [StorageManagedItem]) -> [StorageManagedItem] {
        var deduplicatedByID: [String: StorageManagedItem] = [:]
        for target in targets {
            if let existing = deduplicatedByID[target.id], existing.sizeBytes >= target.sizeBytes {
                continue
            }
            deduplicatedByID[target.id] = target
        }

        let sorted = deduplicatedByID.values.sorted { lhs, rhs in
            if lhs.id.count == rhs.id.count {
                return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
            }
            return lhs.id.count < rhs.id.count
        }

        var normalized: [StorageManagedItem] = []
        normalized.reserveCapacity(sorted.count)

        for candidate in sorted {
            let hasSelectedAncestor = normalized.contains { ancestor in
                isAncestor(path: ancestor.id, of: candidate.id)
            }
            if !hasSelectedAncestor {
                normalized.append(candidate)
            }
        }

        return normalized
    }

    private func isAncestor(path ancestor: String, of descendant: String) -> Bool {
        if ancestor == descendant {
            return true
        }
        return descendant.hasPrefix(ancestor + "/")
    }

    private func deduplicate(_ items: [StorageManagedItem]) -> [StorageManagedItem] {
        var deduplicated: [String: StorageManagedItem] = [:]
        for item in items {
            if let existing = deduplicated[item.id], existing.sizeBytes >= item.sizeBytes {
                continue
            }
            deduplicated[item.id] = item
        }
        return Array(deduplicated.values)
    }

    private func sortDescendingBySizeThenName(_ lhs: StorageManagedItem, _ rhs: StorageManagedItem) -> Bool {
        if lhs.sizeBytes == rhs.sizeBytes {
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return lhs.sizeBytes > rhs.sizeBytes
    }

    private func sizeForItem(at url: URL, fileManager: FileManager) -> UInt64 {
        let keySet: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let values = try? url.resourceValues(forKeys: keySet) else {
            return fallbackFileSize(at: url, fileManager: fileManager)
        }

        if values.isDirectory == true {
            return directorySize(at: url, fileManager: fileManager)
        }

        if let byteCount = values.totalFileAllocatedSize ?? values.fileAllocatedSize, byteCount > 0 {
            return UInt64(byteCount)
        }

        return fallbackFileSize(at: url, fileManager: fileManager)
    }

    private func directorySize(at url: URL, fileManager: FileManager) -> UInt64 {
        let keySet: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keySet),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if Task.isCancelled {
                break
            }
            guard let values = try? fileURL.resourceValues(forKeys: keySet) else {
                continue
            }
            if values.isDirectory == true {
                continue
            }
            if let byteCount = values.totalFileAllocatedSize ?? values.fileAllocatedSize, byteCount > 0 {
                total &+= UInt64(byteCount)
            }
        }

        return total
    }

    private func fallbackFileSize(at url: URL, fileManager: FileManager) -> UInt64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return 0
        }
        return numberValue(from: attributes[.size])
    }

    private func numberValue(from value: Any?) -> UInt64 {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        if let direct = value as? UInt64 {
            return direct
        }
        if let direct = value as? Int64 {
            return direct > 0 ? UInt64(direct) : 0
        }
        if let direct = value as? Int {
            return direct > 0 ? UInt64(direct) : 0
        }
        return 0
    }

    private func cachedResult(for fingerprint: String) -> StorageScanResult? {
        Self.scanCacheLock.lock()
        defer { Self.scanCacheLock.unlock() }

        guard Self.cachedScanFingerprint == fingerprint,
              let timestamp = Self.cachedScanTimestamp,
              Date().timeIntervalSince(timestamp) < Self.scanCacheTTL else {
            return nil
        }
        return Self.cachedScanResult
    }

    private func storeCachedResult(_ result: StorageScanResult, for fingerprint: String) {
        Self.scanCacheLock.lock()
        defer { Self.scanCacheLock.unlock() }
        Self.cachedScanFingerprint = fingerprint
        Self.cachedScanResult = result
        Self.cachedScanTimestamp = Date()
    }

    private func invalidateCachedResult() {
        Self.scanCacheLock.lock()
        defer { Self.scanCacheLock.unlock() }
        Self.cachedScanFingerprint = nil
        Self.cachedScanResult = nil
        Self.cachedScanTimestamp = nil
    }

    private func scanFingerprint(
        customFolders: [URL],
        homeDirectory: URL,
        fileManager: FileManager
    ) -> String {
        var paths = [
            "/Applications",
            homeDirectory.appendingPathComponent("Applications", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true).path,
            "/Library/Caches",
            homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Containers", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Logs", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Preferences", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Developer/CoreSimulator", isDirectory: true).path,
            homeDirectory.appendingPathComponent(".npm", isDirectory: true).path,
            homeDirectory.appendingPathComponent(".pnpm-store", isDirectory: true).path,
            homeDirectory.appendingPathComponent(".cache/yarn", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Caches/Yarn", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Caches/pnpm", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Developer", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Projects", isDirectory: true).path
        ]

        paths.append(contentsOf: customFolders.map { $0.standardizedFileURL.path })
        paths.sort()

        let components = paths.map { pathSignature(for: $0, fileManager: fileManager) }
        return components.joined(separator: "||")
    }

    private func pathSignature(for path: String, fileManager: FileManager) -> String {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard fileManager.fileExists(atPath: normalizedPath),
              let attributes = try? fileManager.attributesOfItem(atPath: normalizedPath) else {
            return "\(normalizedPath)|0"
        }

        let modificationDateMillis: Int64
        if let modificationDate = attributes[.modificationDate] as? Date {
            modificationDateMillis = Int64(modificationDate.timeIntervalSince1970 * 1_000)
        } else {
            modificationDateMillis = 0
        }

        let sizeBytes = numberValue(from: attributes[.size])
        let inode = numberValue(from: attributes[.systemFileNumber])
        return "\(normalizedPath)|1|\(modificationDateMillis)|\(sizeBytes)|\(inode)"
    }

    private func mapDeletionError(_ error: Error) -> StorageDeletionOutcome {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .notFound
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError, NSFileWriteVolumeReadOnlyError:
                return .permissionDenied
            default:
                break
            }
        }

        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case Int(EPERM), Int(EACCES), Int(EROFS):
                return .permissionDenied
            case Int(ENOENT):
                return .notFound
            default:
                return .failed(code: Int32(nsError.code))
            }
        }

        return .failed(code: Int32(nsError.code))
    }
}
