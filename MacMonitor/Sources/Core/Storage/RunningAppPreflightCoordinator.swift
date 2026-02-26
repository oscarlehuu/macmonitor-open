import AppKit
import Foundation

enum RunningAppPreflightOutcome: Equatable, Sendable {
    case notAppBundle
    case notRunning
    case terminatedGracefully
    case forceTerminated
    case stillRunning
}

struct RunningAppPreflightResult: Equatable, Sendable {
    let itemID: String
    let displayName: String
    let outcome: RunningAppPreflightOutcome
}

struct RunningAppPreflightSummary: Equatable, Sendable {
    let results: [RunningAppPreflightResult]

    func itemIDs(matching outcome: RunningAppPreflightOutcome) -> Set<String> {
        Set(
            results.compactMap { result in
                result.outcome == outcome ? result.itemID : nil
            }
        )
    }
}

@MainActor
protocol RunningAppPreflightCoordinating {
    func gracefulQuitPreflight(for items: [StorageManagedItem]) async -> RunningAppPreflightSummary
    func forceQuit(for items: [StorageManagedItem]) async -> RunningAppPreflightSummary
}

@MainActor
protocol RunningApplicationListing {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplication]
    func allRunningApplications() -> [RunningApplication]
}

@MainActor
protocol RunningApplication: AnyObject {
    var processIdentifier: pid_t { get }
    var bundleURL: URL? { get }
    var isTerminated: Bool { get }
    @discardableResult func terminate() -> Bool
    @discardableResult func forceTerminate() -> Bool
}

extension NSRunningApplication: RunningApplication {}

@MainActor
struct WorkspaceRunningApplicationListing: RunningApplicationListing {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    }

    func allRunningApplications() -> [RunningApplication] {
        NSWorkspace.shared.runningApplications
    }
}

@MainActor
protocol RunningAppPollSleeping {
    func sleep(seconds: TimeInterval) async
}

@MainActor
struct TaskRunningAppPollSleeper: RunningAppPollSleeping {
    func sleep(seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

@MainActor
final class RunningAppPreflightCoordinator: RunningAppPreflightCoordinating {
    private enum Action {
        case graceful
        case force
    }

    private let listing: RunningApplicationListing
    private let sleeper: RunningAppPollSleeping
    private let gracefulTimeoutSeconds: TimeInterval
    private let pollIntervalSeconds: TimeInterval

    init(
        listing: RunningApplicationListing = WorkspaceRunningApplicationListing(),
        sleeper: RunningAppPollSleeping = TaskRunningAppPollSleeper(),
        gracefulTimeoutSeconds: TimeInterval = 10,
        pollIntervalSeconds: TimeInterval = 0.25
    ) {
        self.listing = listing
        self.sleeper = sleeper
        self.gracefulTimeoutSeconds = gracefulTimeoutSeconds
        self.pollIntervalSeconds = pollIntervalSeconds
    }

    func gracefulQuitPreflight(for items: [StorageManagedItem]) async -> RunningAppPreflightSummary {
        await runPreflight(for: items, action: .graceful)
    }

    func forceQuit(for items: [StorageManagedItem]) async -> RunningAppPreflightSummary {
        await runPreflight(for: items, action: .force)
    }

    private func runPreflight(for items: [StorageManagedItem], action: Action) async -> RunningAppPreflightSummary {
        var results: [RunningAppPreflightResult] = []
        results.reserveCapacity(items.count)

        for item in items {
            guard item.kind == .appBundle else {
                results.append(
                    RunningAppPreflightResult(
                        itemID: item.id,
                        displayName: item.displayName,
                        outcome: .notAppBundle
                    )
                )
                continue
            }

            let runningApplications = resolveRunningApplications(for: item)
            guard !runningApplications.isEmpty else {
                results.append(
                    RunningAppPreflightResult(
                        itemID: item.id,
                        displayName: item.displayName,
                        outcome: .notRunning
                    )
                )
                continue
            }

            switch action {
            case .graceful:
                for application in runningApplications {
                    _ = application.terminate()
                }
            case .force:
                for application in runningApplications {
                    _ = application.forceTerminate()
                }
            }

            let terminated = await waitUntilTerminated(runningApplications)
            let outcome: RunningAppPreflightOutcome
            if terminated {
                outcome = action == .graceful ? .terminatedGracefully : .forceTerminated
            } else {
                outcome = .stillRunning
            }

            results.append(
                RunningAppPreflightResult(
                    itemID: item.id,
                    displayName: item.displayName,
                    outcome: outcome
                )
            )
        }

        return RunningAppPreflightSummary(results: results)
    }

    private func resolveRunningApplications(for item: StorageManagedItem) -> [RunningApplication] {
        var matchedByPID: [pid_t: RunningApplication] = [:]

        if let bundleIdentifier = item.bundleIdentifier, !bundleIdentifier.isEmpty {
            for app in listing.runningApplications(withBundleIdentifier: bundleIdentifier) where !app.isTerminated {
                matchedByPID[app.processIdentifier] = app
            }
        }

        if matchedByPID.isEmpty {
            let targetPath = item.url.standardizedFileURL.path
            for app in listing.allRunningApplications() where !app.isTerminated {
                guard let appPath = app.bundleURL?.standardizedFileURL.path else { continue }
                if appPath == targetPath {
                    matchedByPID[app.processIdentifier] = app
                }
            }
        }

        return matchedByPID.values.sorted { lhs, rhs in
            lhs.processIdentifier < rhs.processIdentifier
        }
    }

    private func waitUntilTerminated(_ applications: [RunningApplication]) async -> Bool {
        guard !applications.isEmpty else { return true }
        if applications.allSatisfy(\.isTerminated) {
            return true
        }

        let timeout = max(gracefulTimeoutSeconds, 0)
        let interval = max(pollIntervalSeconds, 0.001)
        let pollCount = max(1, Int(ceil(timeout / interval)))

        for _ in 0..<pollCount {
            await sleeper.sleep(seconds: interval)
            if applications.allSatisfy(\.isTerminated) {
                return true
            }
        }

        return applications.allSatisfy(\.isTerminated)
    }
}
