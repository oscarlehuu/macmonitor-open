import Combine
import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class AppUpdateController: NSObject, ObservableObject {
    @Published private(set) var updatesEnabled: Bool
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var canRestartToInstallUpdate = false
    @Published private(set) var statusMessage: String
    @Published private(set) var detailMessage: String?

#if canImport(Sparkle)
    private lazy var updaterController: SPUStandardUpdaterController? = {
        guard updatesEnabled else { return nil }
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()

    private var immediateInstallHandler: (() -> Void)?
#endif

    override init() {
        let feedURL = Self.trimmedInfoValue(forKey: "SUFeedURL")
        let publicKey = Self.trimmedInfoValue(forKey: "SUPublicEDKey")
        let updatesEnabled = (feedURL != nil && publicKey != nil)
        self.updatesEnabled = updatesEnabled
        self.canCheckForUpdates = updatesEnabled
#if canImport(Sparkle)
        self.statusMessage = updatesEnabled ? "Ready to check for updates." : "In-app updates are disabled."
#else
        self.statusMessage = "In-app updates are unavailable in this build."
#endif
        self.detailMessage = nil

        super.init()

#if canImport(Sparkle)
        if updatesEnabled {
            _ = updaterController
            refreshCapabilities()
        } else {
            detailMessage = "Set SPARKLE_APPCAST_URL and SPARKLE_PUBLIC_ED_KEY to enable updates."
        }
#else
        detailMessage = "Sparkle dependency is not linked in this build."
#endif
    }

    func checkForUpdates() {
#if canImport(Sparkle)
        guard updatesEnabled, let updater = updaterController?.updater else { return }
        statusMessage = "Checking for updates..."
        detailMessage = nil
        updater.checkForUpdates()
        refreshCapabilities(from: updater)
#else
        statusMessage = "In-app updates are unavailable in this build."
#endif
    }

    func restartToInstallUpdate() {
#if canImport(Sparkle)
        guard let immediateInstallHandler else { return }
        statusMessage = "Restarting to install update..."
        detailMessage = nil
        canRestartToInstallUpdate = false
        self.immediateInstallHandler = nil
        immediateInstallHandler()
#endif
    }

#if canImport(Sparkle)
    private func refreshCapabilities(from updater: SPUUpdater? = nil) {
        let activeUpdater = updater ?? updaterController?.updater
        canCheckForUpdates = activeUpdater?.canCheckForUpdates ?? false
    }
#else
    private func refreshCapabilities() {
        canCheckForUpdates = false
    }
#endif

    private static func trimmedInfoValue(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if canImport(Sparkle)
@MainActor
extension AppUpdateController: @preconcurrency SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        statusMessage = "Update \(item.displayVersionString) is available."
        detailMessage = "Downloading release assets..."
        refreshCapabilities(from: updater)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        statusMessage = "MacMonitor is up to date."
        detailMessage = nil
        refreshCapabilities(from: updater)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        statusMessage = "Update \(item.displayVersionString) is ready."
        detailMessage = "Restart to install when you are ready."
        refreshCapabilities(from: updater)
    }

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        self.immediateInstallHandler = immediateInstallHandler
        canRestartToInstallUpdate = true
        statusMessage = "Update \(item.displayVersionString) downloaded."
        detailMessage = "Use Restart to Update to apply the release now."
        refreshCapabilities(from: updater)
        return true
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        statusMessage = "Update failed."
        detailMessage = error.localizedDescription
        canRestartToInstallUpdate = false
        immediateInstallHandler = nil
        refreshCapabilities(from: updater)
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        if let error {
            statusMessage = "Update check failed."
            detailMessage = error.localizedDescription
        }
        refreshCapabilities(from: updater)
    }
}
#endif
