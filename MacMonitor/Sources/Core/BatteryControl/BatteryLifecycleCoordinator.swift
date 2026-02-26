import AppKit
import Foundation

enum BatteryLifecycleEvent: String, Equatable {
    case appDidLaunch
    case appWillTerminate
    case willSleep
    case didWake
    case userSessionDidBecomeActive
    case userSessionDidResignActive
}

@MainActor
final class BatteryLifecycleCoordinator {
    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private let onEvent: (BatteryLifecycleEvent) -> Void

    private var observers: [NSObjectProtocol] = []
    private var hasStarted = false

    init(
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        onEvent: @escaping (BatteryLifecycleEvent) -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.onEvent = onEvent
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        observers.append(
            notificationCenter.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onEvent(.appWillTerminate)
                }
            }
        )

        observers.append(
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onEvent(.willSleep)
                }
            }
        )

        observers.append(
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onEvent(.didWake)
                }
            }
        )

        observers.append(
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onEvent(.userSessionDidBecomeActive)
                }
            }
        )

        observers.append(
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onEvent(.userSessionDidResignActive)
                }
            }
        )

        onEvent(.appDidLaunch)
    }

    func stop() {
        hasStarted = false
        for observer in observers {
            notificationCenter.removeObserver(observer)
            workspaceNotificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }
}
