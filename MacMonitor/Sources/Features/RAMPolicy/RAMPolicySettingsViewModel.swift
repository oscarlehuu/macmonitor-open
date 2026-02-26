import AppKit
import Foundation

struct RunningAppOption: Identifiable, Hashable {
    let bundleID: String
    let displayName: String

    var id: String { bundleID }
}

struct RAMPolicyDraft: Equatable {
    var bundleID: String
    var displayName: String
    var limitMode: RAMPolicyLimitMode
    var limitValueText: String
    var triggerMode: RAMPolicyTriggerMode
    var sustainedSeconds: Int
    var notifyCooldownSeconds: Int
    var enabled: Bool

    init(
        bundleID: String = "",
        displayName: String = "",
        limitMode: RAMPolicyLimitMode = .percent,
        limitValueText: String = "10",
        triggerMode: RAMPolicyTriggerMode = .both,
        sustainedSeconds: Int = RAMPolicy.defaultSustainedSeconds,
        notifyCooldownSeconds: Int = RAMPolicy.defaultCooldownSeconds,
        enabled: Bool = true
    ) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.limitMode = limitMode
        self.limitValueText = limitValueText
        self.triggerMode = triggerMode
        self.sustainedSeconds = sustainedSeconds
        self.notifyCooldownSeconds = notifyCooldownSeconds
        self.enabled = enabled
    }

    init(policy: RAMPolicy) {
        bundleID = policy.bundleID
        displayName = policy.displayName
        limitMode = policy.limitMode
        limitValueText = RAMPolicyDraft.formatLimitValue(policy.limitValue)
        triggerMode = policy.triggerMode
        sustainedSeconds = policy.sustainedSeconds
        notifyCooldownSeconds = policy.notifyCooldownSeconds
        enabled = policy.enabled
    }

    private static func formatLimitValue(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return String(rounded)
    }
}

@MainActor
final class RAMPolicySettingsViewModel: ObservableObject {
    @Published private(set) var policies: [RAMPolicy] = []
    @Published private(set) var recentEvents: [RAMPolicyEvent] = []
    @Published private(set) var runningApps: [RunningAppOption] = []
    @Published private(set) var errorMessage: String?

    private let policyStore: RAMPolicyStoring
    private let eventStore: RAMPolicyEventStoring
    private weak var monitor: RAMPolicyMonitoring?
    private let now: () -> Date
    private let runningAppsProvider: @MainActor () -> [RunningAppOption]

    init(
        policyStore: RAMPolicyStoring,
        eventStore: RAMPolicyEventStoring,
        monitor: RAMPolicyMonitoring? = nil,
        now: @escaping () -> Date = Date.init,
        runningAppsProvider: @escaping @MainActor () -> [RunningAppOption] = RAMPolicySettingsViewModel.defaultRunningApps
    ) {
        self.policyStore = policyStore
        self.eventStore = eventStore
        self.monitor = monitor
        self.now = now
        self.runningAppsProvider = runningAppsProvider

        refresh()
    }

    func refresh() {
        policies = policyStore.loadPolicies()
        recentEvents = eventStore.recentEvents(limit: 30)
        runningApps = runningAppsProvider()
        errorMessage = nil
    }

    func makeDraftForNewPolicy() -> RAMPolicyDraft {
        guard let firstApp = runningApps.first else {
            return RAMPolicyDraft()
        }

        return RAMPolicyDraft(bundleID: firstApp.bundleID, displayName: firstApp.displayName)
    }

    func saveDraft(_ draft: RAMPolicyDraft, editingID: UUID?) -> Bool {
        let normalizedBundleID = draft.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBundleID.isEmpty else {
            errorMessage = "Choose an app first."
            return false
        }

        guard let limitValue = parseLimitValue(from: draft.limitValueText) else {
            errorMessage = "Enter a valid RAM limit value."
            return false
        }

        if draft.limitMode == .percent, limitValue > 100 {
            errorMessage = "Percent limit must be between 0 and 100."
            return false
        }

        let displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? normalizedBundleID
            : draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        var policy = RAMPolicy(
            id: editingID ?? UUID(),
            bundleID: normalizedBundleID,
            displayName: displayName,
            limitMode: draft.limitMode,
            limitValue: limitValue,
            triggerMode: draft.triggerMode,
            sustainedSeconds: draft.sustainedSeconds,
            notifyCooldownSeconds: draft.notifyCooldownSeconds,
            enabled: draft.enabled,
            updatedAt: now()
        ).normalized

        if !policy.isValid {
            errorMessage = "Policy is not valid. Check limit and trigger values."
            return false
        }

        do {
            if let existing = policies.first(where: { $0.bundleID == normalizedBundleID && $0.id != policy.id }) {
                // Replace existing app policy in-place so each app has at most one active config in v1.
                try policyStore.deletePolicy(id: existing.id)
            }

            policy.updatedAt = now()
            try policyStore.savePolicy(policy)
            refresh()
            monitor?.evaluateNow()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func setEnabled(_ enabled: Bool, for policyID: UUID) {
        guard var policy = policies.first(where: { $0.id == policyID }) else { return }
        policy.enabled = enabled
        policy.updatedAt = now()

        do {
            try policyStore.savePolicy(policy)
            refresh()
            if enabled {
                monitor?.evaluateNow()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePolicy(id: UUID) {
        do {
            try policyStore.deletePolicy(id: id)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func lastEvent(for policyID: UUID) -> RAMPolicyEvent? {
        recentEvents.first(where: { $0.policyID == policyID })
    }

    func clearError() {
        errorMessage = nil
    }

    private func parseLimitValue(from rawText: String) -> Double? {
        let normalizedText = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalizedText), value > 0 else {
            return nil
        }

        return value
    }

    private static func defaultRunningApps() -> [RunningAppOption] {
        let apps = NSWorkspace.shared.runningApplications
            .compactMap { app -> RunningAppOption? in
                guard let bundleID = app.bundleIdentifier else { return nil }
                let displayName = app.localizedName ?? bundleID
                return RunningAppOption(bundleID: bundleID, displayName: displayName)
            }

        var seen = Set<String>()
        return apps
            .filter { seen.insert($0.bundleID).inserted }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }
}
