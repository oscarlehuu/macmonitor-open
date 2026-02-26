import Foundation
import UserNotifications

protocol RAMPolicyNotifying {
    func notify(breach: RAMPolicyBreach)
}

final class UserNotificationRAMPolicyNotifier: RAMPolicyNotifying {
    private let center: UNUserNotificationCenter
    private let now: () -> Date
    private var requestedAuthorization = false

    init(
        center: UNUserNotificationCenter = .current(),
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.now = now
    }

    func notify(breach: RAMPolicyBreach) {
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "\(breach.policy.displayName) exceeded RAM limit"
        content.body = "Using \(MetricFormatter.bytes(breach.observedBytes)) (limit \(MetricFormatter.bytes(breach.thresholdBytes)))."
        content.sound = .default

        let identifier = "ram-policy-\(breach.policy.id.uuidString)-\(Int(now().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request)
    }

    private func requestAuthorizationIfNeeded() {
        guard !requestedAuthorization else { return }
        requestedAuthorization = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
