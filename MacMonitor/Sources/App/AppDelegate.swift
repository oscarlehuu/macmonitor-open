import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicateLaunch else {
            NSApp.terminate(nil)
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)

        let container = AppContainer()
        self.container = container
        container.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.stop()
    }

    private var isDuplicateLaunch: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier

        // Allow a grace period for relaunch handoff where the old instance
        // may still be alive briefly while the new one starts.
        let maxAttempts = 10
        let delayBetweenAttempts: TimeInterval = 0.5

        for _ in 0..<maxAttempts {
            let runningWithSameBundle = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .filter { $0.processIdentifier != currentPID && !$0.isTerminated }

            if runningWithSameBundle.isEmpty {
                return false
            }

            Thread.sleep(forTimeInterval: delayBetweenAttempts)
        }

        return true
    }
}
