import Darwin
import Foundation
import Security
import ServiceManagement

protocol BatteryHelperInstalling {
    func isHelperInstalled() -> Bool
    func installHelper() -> Result<BatteryHelperInstallMode, BatteryHelperInstallerError>
}

enum BatteryHelperInstallMode {
    case privileged
    case privilegedLaunchDaemon
}

enum BatteryHelperInstallerError: LocalizedError {
    case authorizationFailed(OSStatus)
    case blessFailed(String)
    case bundledHelperMissing
    case launchDaemonInstallFailed(String)
    case installFailed(primary: String, fallback: String)

    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let status):
            return "Authorization failed with status \(status)."
        case .blessFailed(let message):
            return "SMJobBless failed: \(message)"
        case .bundledHelperMissing:
            return "Bundled helper binary was not found in the app bundle."
        case .launchDaemonInstallFailed(let message):
            return "Privileged LaunchDaemon install failed: \(message)"
        case .installFailed(let primary, let fallback):
            return "\(primary) Fallback install also failed: \(fallback)"
        }
    }
}

final class SMJobBlessBatteryHelperInstaller: BatteryHelperInstalling {
    private let helperLabel: String
    private let fileManager: FileManager

    init(
        helperLabel: String = BatteryHelperXPCConstants.helperLabel,
        fileManager: FileManager = .default
    ) {
        self.helperLabel = helperLabel
        self.fileManager = fileManager
    }

    func isHelperInstalled() -> Bool {
        guard isServiceLoaded(inDomain: "system") else {
            return false
        }
        return installedHelperMatchesBundledVersion()
    }

    func installHelper() -> Result<BatteryHelperInstallMode, BatteryHelperInstallerError> {
        if isHelperInstalled() {
            return .success(.privileged)
        }

        // In local/dev builds SMJobBless is commonly unavailable; prefer deterministic LaunchDaemon install first.
        switch installPrivilegedLaunchDaemon() {
        case .success:
            return .success(.privilegedLaunchDaemon)
        case .failure(let daemonError):
            switch installPrivilegedHelper() {
            case .success:
                return .success(.privileged)
            case .failure(let privilegedError):
                return .failure(
                    .installFailed(
                        primary: daemonError.localizedDescription,
                        fallback: privilegedError.localizedDescription
                    )
                )
            }
        }
    }

    private var uidString: String {
        String(getuid())
    }

    private var installedHelperURL: URL {
        URL(fileURLWithPath: "/Library/PrivilegedHelperTools/\(helperLabel)", isDirectory: false)
    }

    private func installPrivilegedHelper() -> Result<Void, BatteryHelperInstallerError> {
        var authorizationRef: AuthorizationRef?
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        let status = AuthorizationCreate(nil, nil, authFlags, &authorizationRef)

        guard status == errAuthorizationSuccess, let authorizationRef else {
            return .failure(.authorizationFailed(status))
        }
        defer {
            AuthorizationFree(authorizationRef, [])
        }

        var blessingError: Unmanaged<CFError>?
        let blessed = SMJobBless(kSMDomainSystemLaunchd, helperLabel as CFString, authorizationRef, &blessingError)

        if blessed {
            return .success(())
        }

        let message = blessingError?.takeRetainedValue().localizedDescription ?? "Unknown error"
        return .failure(.blessFailed(message))
    }

    private func installPrivilegedLaunchDaemon() -> Result<Void, BatteryHelperInstallerError> {
        guard let helperSourceURL = resolveBundledHelperURL() else {
            return .failure(.bundledHelperMissing)
        }

        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("com.oscar.macmonitor.helper-install", isDirectory: true)
        let stagedHelperURL = temporaryDirectory.appendingPathComponent(helperLabel, isDirectory: false)
        let stagedPlistURL = temporaryDirectory.appendingPathComponent("\(helperLabel).plist", isDirectory: false)
        let installedHelperPath = "/Library/PrivilegedHelperTools/\(helperLabel)"
        let launchDaemonPath = "/Library/LaunchDaemons/\(helperLabel).plist"

        do {
            try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: stagedHelperURL.path) {
                try fileManager.removeItem(at: stagedHelperURL)
            }
            try fileManager.copyItem(at: helperSourceURL, to: stagedHelperURL)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stagedHelperURL.path)
            try writeLaunchDaemonPlist(helperExecutablePath: installedHelperPath, to: stagedPlistURL)
        } catch {
            return .failure(.launchDaemonInstallFailed(error.localizedDescription))
        }

        let commands = [
            "/bin/launchctl bootout system/\(helperLabel) >/dev/null 2>&1 || true",
            "/bin/launchctl bootout gui/\(uidString)/\(helperLabel) >/dev/null 2>&1 || true",
            "/bin/mkdir -p /Library/PrivilegedHelperTools",
            "/usr/bin/install -m 755 \(shellQuoted(stagedHelperURL.path)) \(shellQuoted(installedHelperPath))",
            "/usr/sbin/chown root:wheel \(shellQuoted(installedHelperPath))",
            "/bin/mkdir -p /Library/LaunchDaemons",
            "/usr/bin/install -m 644 \(shellQuoted(stagedPlistURL.path)) \(shellQuoted(launchDaemonPath))",
            "/usr/sbin/chown root:wheel \(shellQuoted(launchDaemonPath))",
            "/bin/launchctl bootstrap system \(shellQuoted(launchDaemonPath))",
            "/bin/launchctl kickstart -k system/\(helperLabel)"
        ]

        let shellScript = commands.joined(separator: "; ")
        let appleScript = "do shell script \"\(appleScriptEscaped(shellScript))\" with administrator privileges"
        let result = runProcess(
            executablePath: "/usr/bin/osascript",
            arguments: ["-e", appleScript],
            timeoutSeconds: 90
        )

        if result.terminationStatus != 0 {
            let output = result.output.isEmpty ? "Administrator install command failed." : result.output
            return .failure(.launchDaemonInstallFailed(output))
        }

        guard isServiceLoaded(inDomain: "system") else {
            return .failure(.launchDaemonInstallFailed("LaunchDaemon did not appear in launchctl after install."))
        }

        return .success(())
    }

    private func resolveBundledHelperURL() -> URL? {
        let bundleCandidate = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/\(helperLabel)", isDirectory: false)

        let executableCandidate = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Contents/Library/LaunchServices/\(helperLabel)", isDirectory: false)

        let installedAppCandidate = URL(fileURLWithPath: "/Applications/MacMonitor.app")
            .appendingPathComponent("Contents/Library/LaunchServices/\(helperLabel)", isDirectory: false)

        for candidate in [bundleCandidate, executableCandidate, installedAppCandidate] {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private func installedHelperMatchesBundledVersion() -> Bool {
        guard let bundledHelperURL = resolveBundledHelperURL() else {
            // If the app bundle is malformed we cannot compare versions; keep prior behavior.
            return true
        }

        guard fileManager.fileExists(atPath: installedHelperURL.path),
              let bundledData = try? Data(contentsOf: bundledHelperURL),
              let installedData = try? Data(contentsOf: installedHelperURL) else {
            return false
        }

        return bundledData == installedData
    }

    private func writeLaunchDaemonPlist(helperExecutablePath: String, to plistURL: URL) throws {
        let plist: [String: Any] = [
            "Label": helperLabel,
            "ProgramArguments": [helperExecutablePath],
            "MachServices": [helperLabel: true],
            "RunAtLoad": true,
            "KeepAlive": true
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: [.atomic])
    }

    private func isServiceLoaded(inDomain domain: String) -> Bool {
        runLaunchctl(["print", "\(domain)/\(helperLabel)"]).terminationStatus == 0
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private func runLaunchctl(_ arguments: [String]) -> ProcessResult {
        runProcess(executablePath: "/bin/launchctl", arguments: arguments, timeoutSeconds: nil)
    }

    private func runProcess(
        executablePath: String,
        arguments: [String],
        timeoutSeconds: TimeInterval?
    ) -> ProcessResult {
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        let outputData: Data
        do {
            try process.run()

            if let timeoutSeconds {
                let deadline = Date().addingTimeInterval(timeoutSeconds)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.1)
                }

                if process.isRunning {
                    process.terminate()
                    return ProcessResult(
                        terminationStatus: -1,
                        output: "Command timed out after \(Int(timeoutSeconds)) seconds."
                    )
                }
            } else {
                process.waitUntilExit()
            }

            outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        } catch {
            return ProcessResult(
                terminationStatus: -1,
                output: error.localizedDescription
            )
        }

        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ProcessResult(terminationStatus: process.terminationStatus, output: output)
    }
}

private struct ProcessResult {
    let terminationStatus: Int32
    let output: String
}
