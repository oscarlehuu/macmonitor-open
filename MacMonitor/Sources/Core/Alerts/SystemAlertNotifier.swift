import Foundation
import UserNotifications

@MainActor
protocol SystemAlertNotifying {
    func notify(alerts: [SystemAlert], cooldown: TimeInterval)
}

@MainActor
final class UserNotificationSystemAlertNotifier: SystemAlertNotifying {
    private let center: UNUserNotificationCenter
    private let now: () -> Date
    private var lastNotificationByKind: [SystemAlertKind: Date] = [:]
    private var requestedAuthorization = false

    init(
        center: UNUserNotificationCenter = .current(),
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.now = now
    }

    func notify(alerts: [SystemAlert], cooldown: TimeInterval) {
        guard !alerts.isEmpty else { return }
        requestAuthorizationIfNeeded()

        for alert in alerts {
            if shouldSkip(alert: alert, cooldown: cooldown) {
                continue
            }
            enqueueNotification(for: alert)
            lastNotificationByKind[alert.kind] = now()
        }
    }

    private func shouldSkip(alert: SystemAlert, cooldown: TimeInterval) -> Bool {
        guard let lastNotification = lastNotificationByKind[alert.kind] else {
            return false
        }
        return now().timeIntervalSince(lastNotification) < max(0, cooldown)
    }

    private func requestAuthorizationIfNeeded() {
        guard !requestedAuthorization else { return }
        requestedAuthorization = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func enqueueNotification(for alert: SystemAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "system-alert-\(alert.kind.rawValue)",
            content: content,
            trigger: nil
        )

        center.add(request) { _ in }
    }
}
