import Combine
import Foundation

enum TrendWindow: String, CaseIterable, Codable, Identifiable {
    case last24Hours
    case last7Days

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last24Hours:
            return "24h"
        case .last7Days:
            return "7d"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .last24Hours:
            return 24 * 60 * 60
        case .last7Days:
            return 7 * 24 * 60 * 60
        }
    }
}

struct TrendSample: Identifiable, Equatable {
    let timestamp: Date
    let value: Double

    var id: TimeInterval { timestamp.timeIntervalSince1970 }
}

@MainActor
final class SystemSummaryViewModel: ObservableObject {
    enum Screen {
        case temperature
        case battery
        case ram
        case storage
        case trends
        case storageManagement
        case settings
        case ramPolicyManager
    }

    @Published private(set) var snapshot: SystemSnapshot?
    @Published private(set) var history: [SystemSnapshot] = []
    @Published private(set) var recentSystemAlerts: [SystemAlert] = []
    @Published var selectedTrendWindow: TrendWindow = .last24Hours
    @Published private(set) var screen: Screen = .battery

    let settings: SettingsStore

    private let engine: MetricsEngine
    private let snapshotStore: SnapshotStore
    private let appGroupSnapshotStore: AppGroupSnapshotStore?
    private let alertPolicyEngine: SystemAlertPolicyEngine
    private let alertNotifier: SystemAlertNotifying
    private let now: () -> Date
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false

    init(
        engine: MetricsEngine,
        snapshotStore: SnapshotStore,
        settings: SettingsStore,
        appGroupSnapshotStore: AppGroupSnapshotStore? = nil,
        alertPolicyEngine: SystemAlertPolicyEngine = SystemAlertPolicyEngine(),
        alertNotifier: SystemAlertNotifying = UserNotificationSystemAlertNotifier(),
        now: @escaping () -> Date = Date.init
    ) {
        self.engine = engine
        self.snapshotStore = snapshotStore
        self.settings = settings
        self.appGroupSnapshotStore = appGroupSnapshotStore
        self.alertPolicyEngine = alertPolicyEngine
        self.alertNotifier = alertNotifier
        self.now = now
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        history = snapshotStore.loadHistory()
        snapshot = history.last
        if let snapshot {
            appGroupSnapshotStore?.write(snapshot: snapshot, history: history, referenceDate: now())
            evaluateAndNotifyAlerts(for: snapshot)
        }

        engine.$latestSnapshot
            .compactMap { $0 }
            .sink { [weak self] newSnapshot in
                guard let self else { return }
                snapshot = newSnapshot
                history.append(newSnapshot)
                if history.count > 3_500 {
                    history = Array(history.suffix(3_500))
                }
                snapshotStore.append(newSnapshot)
                appGroupSnapshotStore?.write(snapshot: newSnapshot, history: history, referenceDate: now())
                evaluateAndNotifyAlerts(for: newSnapshot)
            }
            .store(in: &cancellables)

        engine.start()
    }

    func stop() {
        guard hasStarted else { return }
        hasStarted = false
        engine.stop()
        cancellables.removeAll()
    }

    func refreshNow() {
        engine.refreshNow()
    }

    func showSettings() {
        screen = .settings
    }

    func showSummary() {
        showBattery()
    }

    func showRAMDetails() {
        showRAM()
    }

    func showBattery() {
        screen = .battery
    }

    func showTemperature() {
        screen = .temperature
    }

    func showRAM() {
        screen = .ram
    }

    func showStorage() {
        screen = .storage
    }

    func showTrends() {
        screen = .trends
    }

    func showStorageManagement() {
        screen = .storageManagement
    }

    func showRAMPolicyManager() {
        screen = .ramPolicyManager
    }

    var isStale: Bool {
        guard let snapshot else { return true }
        let maxAge = settings.refreshInterval.seconds * 2.0
        return snapshot.age() > maxAge
    }

    var thermalState: ThermalState {
        snapshot?.thermal.state ?? .unknown
    }

    var statusTooltip: String {
        guard let snapshot else {
            return "MacMonitor: waiting for data"
        }

        let memoryUsage = MetricFormatter.percent(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes)
        let storageUsage = MetricFormatter.percent(used: snapshot.storage.usedBytes, total: snapshot.storage.totalBytes)
        let cpuUsage = MetricFormatter.percentValue(snapshot.cpu.normalizedPercent)
        let networkUsage = "\(MetricFormatter.bytesPerSecond(snapshot.network.downloadBytesPerSecond)) down, \(MetricFormatter.bytesPerSecond(snapshot.network.uploadBytesPerSecond)) up"
        let batteryText: String
        if let percentage = snapshot.battery.percentage {
            batteryText = "\(percentage)% \(snapshot.battery.chargeState.title)"
        } else {
            batteryText = "Unavailable"
        }
        return "Thermal: \(snapshot.thermal.state.title) | RAM: \(memoryUsage) | Storage: \(storageUsage) | CPU: \(cpuUsage) | Net: \(networkUsage) | Battery: \(batteryText)"
    }

    func snapshots(for window: TrendWindow) -> [SystemSnapshot] {
        let cutoff = now().addingTimeInterval(-window.duration)
        return history
            .filter { $0.timestamp >= cutoff }
            .sorted(by: { $0.timestamp < $1.timestamp })
    }

    func memoryTrend(window: TrendWindow) -> [TrendSample] {
        snapshots(for: window).map {
            TrendSample(timestamp: $0.timestamp, value: min(max($0.memory.usageRatio * 100, 0), 100))
        }
    }

    func storageTrend(window: TrendWindow) -> [TrendSample] {
        snapshots(for: window).map {
            TrendSample(timestamp: $0.timestamp, value: min(max($0.storage.usageRatio * 100, 0), 100))
        }
    }

    func cpuTrend(window: TrendWindow) -> [TrendSample] {
        snapshots(for: window).compactMap { snapshot in
            guard let value = snapshot.cpu.normalizedPercent else { return nil }
            return TrendSample(timestamp: snapshot.timestamp, value: value)
        }
    }

    func thermalTrend(window: TrendWindow) -> [TrendSample] {
        snapshots(for: window).map {
            TrendSample(timestamp: $0.timestamp, value: Double($0.thermal.state.severity))
        }
    }

    func batteryTrend(window: TrendWindow) -> [TrendSample] {
        snapshots(for: window).compactMap { snapshot in
            guard let percent = snapshot.battery.percentage else { return nil }
            return TrendSample(timestamp: snapshot.timestamp, value: Double(percent))
        }
    }

    func isTrendDataStale(for window: TrendWindow) -> Bool {
        guard let latestTimestamp = snapshots(for: window).last?.timestamp else {
            return true
        }
        return now().timeIntervalSince(latestTimestamp) > (settings.refreshInterval.seconds * 2.5)
    }

    func trendCoverageMessage(for window: TrendWindow) -> String? {
        guard let firstTimestamp = history.first?.timestamp,
              let lastTimestamp = history.last?.timestamp else {
            return "Collecting history..."
        }

        let available = max(lastTimestamp.timeIntervalSince(firstTimestamp), 0)
        guard available < window.duration else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2

        let availableText = formatter.string(from: available) ?? "<1h"
        let requiredText = formatter.string(from: window.duration) ?? window.title
        return "Showing \(availableText) of \(requiredText) history."
    }

    private func evaluateAndNotifyAlerts(for snapshot: SystemSnapshot) {
        let alerts = alertPolicyEngine.evaluate(
            snapshot: snapshot,
            history: history,
            settings: settings.systemAlertSettings,
            referenceDate: now()
        )

        if !alerts.isEmpty {
            recentSystemAlerts = Array((alerts + recentSystemAlerts).prefix(10))
        }

        let cooldown = TimeInterval(settings.systemAlertSettings.cooldownMinutes * 60)
        alertNotifier.notify(alerts: alerts, cooldown: cooldown)
    }
}
