import Combine
import Foundation

enum BatteryScheduleDraftAction: String, CaseIterable, Identifiable {
    case setChargeLimit
    case startTopUp
    case startDischarge
    case pauseCharging

    var id: String { rawValue }

    var title: String {
        switch self {
        case .setChargeLimit:
            return "Set Limit"
        case .startTopUp:
            return "Top Up"
        case .startDischarge:
            return "Discharge"
        case .pauseCharging:
            return "Pause Charging"
        }
    }

    var usesTargetPercent: Bool {
        switch self {
        case .setChargeLimit, .startDischarge:
            return true
        case .startTopUp, .pauseCharging:
            return false
        }
    }

    func makeScheduledAction(targetPercent: Int) -> BatteryScheduledAction {
        switch self {
        case .setChargeLimit:
            return .setChargeLimit(targetPercent)
        case .startTopUp:
            return .startTopUp
        case .startDischarge:
            return .startDischarge(targetPercent: targetPercent)
        case .pauseCharging:
            return .pauseCharging
        }
    }
}

@MainActor
final class BatteryScheduleViewModel: ObservableObject {
    @Published var draftAction: BatteryScheduleDraftAction = .setChargeLimit
    @Published var draftTargetPercent: Int = 80
    @Published var draftScheduledAt: Date

    @Published private(set) var pendingTasks: [BatteryScheduledTask] = []
    @Published private(set) var lastExecutionSummary: String?
    @Published private(set) var lastFailureReason: String?
    @Published private(set) var errorMessage: String?

    private let scheduleCoordinator: BatteryScheduleCoordinator
    private let policyCoordinator: BatteryPolicyCoordinator
    private let now: () -> Date
    private let minimumLeadTime: TimeInterval
    private let defaultLeadTime: TimeInterval

    private var cancellables = Set<AnyCancellable>()

    init(
        scheduleCoordinator: BatteryScheduleCoordinator,
        policyCoordinator: BatteryPolicyCoordinator,
        minimumLeadTime: TimeInterval = 60,
        defaultLeadTime: TimeInterval = 5 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.scheduleCoordinator = scheduleCoordinator
        self.policyCoordinator = policyCoordinator
        self.minimumLeadTime = max(30, minimumLeadTime)
        self.defaultLeadTime = max(60, defaultLeadTime)
        self.now = now
        draftScheduledAt = Self.roundedUpQuarterHour(from: now().addingTimeInterval(max(60, defaultLeadTime)))

        bind()
        refreshFromCoordinator()
    }

    var minimumAllowedDate: Date {
        now().addingTimeInterval(minimumLeadTime)
    }

    func scheduleDraftTask() -> Bool {
        guard draftScheduledAt >= minimumAllowedDate else {
            errorMessage = "Choose a time at least 1 minute in the future."
            return false
        }

        if draftAction.usesTargetPercent, !(50...95).contains(draftTargetPercent) {
            errorMessage = "Target percent must be between 50% and 95%."
            return false
        }

        let action = draftAction.makeScheduledAction(targetPercent: draftTargetPercent)
        scheduleCoordinator.schedule(action: action, at: draftScheduledAt)
        errorMessage = nil
        draftScheduledAt = Self.roundedUpQuarterHour(from: max(draftScheduledAt, minimumAllowedDate).addingTimeInterval(defaultLeadTime))
        return true
    }

    func cancelTask(_ taskID: UUID) {
        scheduleCoordinator.cancel(taskID: taskID)
    }

    func formattedAction(_ action: BatteryScheduledAction) -> String {
        switch action {
        case .setChargeLimit(let limit):
            return "Set limit to \(limit)%"
        case .startTopUp:
            return "Start top up"
        case .startDischarge(let targetPercent):
            return "Discharge to \(targetPercent)%"
        case .pauseCharging:
            return "Pause charging"
        }
    }

    func formattedScheduledTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    func formattedRelativeTime(_ date: Date) -> String {
        MetricFormatter.relativeTime(from: date, reference: now())
    }

    private func bind() {
        scheduleCoordinator.$pendingTasks
            .sink { [weak self] tasks in
                self?.pendingTasks = Self.sortTasks(tasks)
            }
            .store(in: &cancellables)

        scheduleCoordinator.$lastExecutionMessage
            .sink { [weak self] message in
                self?.lastExecutionSummary = message
            }
            .store(in: &cancellables)

        policyCoordinator.$recentEvents
            .sink { [weak self] events in
                self?.lastFailureReason = Self.latestScheduleFailure(from: events)
            }
            .store(in: &cancellables)
    }

    private func refreshFromCoordinator() {
        pendingTasks = Self.sortTasks(scheduleCoordinator.pendingTasks)
        lastExecutionSummary = scheduleCoordinator.lastExecutionMessage
        lastFailureReason = Self.latestScheduleFailure(from: policyCoordinator.recentEvents)
    }

    private static func sortTasks(_ tasks: [BatteryScheduledTask]) -> [BatteryScheduledTask] {
        tasks.sorted { lhs, rhs in
            if lhs.scheduledAt == rhs.scheduledAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.scheduledAt < rhs.scheduledAt
        }
    }

    private static func roundedUpQuarterHour(from date: Date) -> Date {
        let secondsInQuarterHour = 15 * 60
        let currentTime = date.timeIntervalSince1970
        let rounded = ceil(currentTime / Double(secondsInQuarterHour)) * Double(secondsInQuarterHour)
        return Date(timeIntervalSince1970: rounded)
    }

    private static func latestScheduleFailure(from events: [BatteryControlEvent]) -> String? {
        events.first(where: { $0.source == .schedule && !$0.accepted })?.message
    }
}
