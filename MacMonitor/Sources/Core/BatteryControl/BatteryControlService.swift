import Foundation

@MainActor
final class BatteryControlService: ObservableObject {
    @Published private(set) var availability: BatteryControlAvailability
    @Published private(set) var effectiveState: BatteryControlState = .unavailable
    @Published private(set) var lastCommand: BatteryControlCommand?
    @Published private(set) var lastCommandResult: BatteryControlCommandResult?
    @Published private(set) var recentEvents: [BatteryControlEvent] = []

    private let backend: BatteryControlBackend
    private let eventStore: BatteryEventStoring
    private let now: () -> Date

    init(
        backend: BatteryControlBackend,
        eventStore: BatteryEventStoring,
        now: @escaping () -> Date = Date.init
    ) {
        self.backend = backend
        self.eventStore = eventStore
        self.now = now
        self.availability = backend.availability
        refreshRecentEvents()
        eventStore.pruneExpiredEvents(referenceDate: now())
    }

    func execute(
        _ command: BatteryControlCommand,
        resultingState: BatteryControlState,
        source: BatteryControlEventSource,
        reason: String,
        batteryPercent: Int?
    ) async -> BatteryControlCommandResult {
        availability = backend.availability
        let result: BatteryControlCommandResult

        switch availability {
        case .available:
            let backend = self.backend
            result = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(returning: backend.execute(command))
                }
            }
        case .unavailable(let unavailableReason):
            result = .failure(unavailableReason)
        }

        if result.accepted {
            effectiveState = resultingState
        }
        lastCommand = command
        lastCommandResult = result

        recordEvent(
            source: source,
            state: resultingState,
            command: command,
            accepted: result.accepted,
            message: [reason, result.message].compactMap { $0 }.joined(separator: " "),
            batteryPercent: batteryPercent
        )
        return result
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        let result = backend.installHelperIfNeeded()
        availability = backend.availability

        recordEvent(
            source: .system,
            state: effectiveState,
            command: nil,
            accepted: result.accepted,
            message: result.message ?? "Helper install request completed.",
            batteryPercent: nil
        )

        return result
    }

    func installHelperIfNeededAsync() async -> BatteryControlCommandResult {
        let backend = self.backend
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<BatteryControlCommandResult, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: backend.installHelperIfNeeded())
            }
        }

        availability = self.backend.availability
        recordEvent(
            source: .system,
            state: effectiveState,
            command: nil,
            accepted: result.accepted,
            message: result.message ?? "Helper install request completed.",
            batteryPercent: nil
        )

        return result
    }

    func recordState(
        _ state: BatteryControlState,
        source: BatteryControlEventSource,
        reason: String,
        batteryPercent: Int?
    ) {
        effectiveState = state
        recordEvent(
            source: source,
            state: state,
            command: nil,
            accepted: true,
            message: reason,
            batteryPercent: batteryPercent
        )
    }

    func refreshRecentEvents(limit: Int = 20) {
        recentEvents = eventStore.recentEvents(limit: limit)
    }

    private func recordEvent(
        source: BatteryControlEventSource,
        state: BatteryControlState,
        command: BatteryControlCommand?,
        accepted: Bool,
        message: String,
        batteryPercent: Int?
    ) {
        let event = BatteryControlEvent(
            timestamp: now(),
            source: source,
            state: state,
            command: command,
            accepted: accepted,
            message: message,
            batteryPercent: batteryPercent
        )

        do {
            try eventStore.append(event)
        } catch {
            // Keep control path resilient even when diagnostics persistence fails.
        }
        refreshRecentEvents()
    }
}
