import Combine
import Foundation

@MainActor
final class MetricsEngine: ObservableObject {
    @Published private(set) var latestSnapshot: SystemSnapshot?

    private let memoryCollector: MemoryCollecting
    private let storageCollector: StorageCollecting
    private let batteryCollector: BatteryCollecting
    private let thermalCollector: ThermalCollecting
    private let cpuCollector: CPUCollecting
    private let networkCollector: NetworkCollecting
    private let gpuCollector: GPUCollecting
    private let settings: SettingsStore
    private let now: () -> Date

    private var timerCancellable: AnyCancellable?
    private var refreshIntervalCancellable: AnyCancellable?
    private var batteryChangeCancellable: AnyCancellable?
    private var thermalChangeCancellable: AnyCancellable?

    init(
        memoryCollector: MemoryCollecting,
        storageCollector: StorageCollecting,
        batteryCollector: BatteryCollecting,
        thermalCollector: ThermalCollecting,
        cpuCollector: CPUCollecting,
        networkCollector: NetworkCollecting,
        gpuCollector: GPUCollecting = DefaultGPUCollector(),
        settings: SettingsStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.memoryCollector = memoryCollector
        self.storageCollector = storageCollector
        self.batteryCollector = batteryCollector
        self.thermalCollector = thermalCollector
        self.cpuCollector = cpuCollector
        self.networkCollector = networkCollector
        self.gpuCollector = gpuCollector
        self.settings = settings
        self.now = now
    }

    func start() {
        bindSettings()
        bindBatteryChanges()
        bindThermalChanges()
        scheduleTimer(using: settings.refreshInterval)
        refresh(reason: .startup)
    }

    func stop() {
        timerCancellable?.cancel()
        refreshIntervalCancellable?.cancel()
        batteryChangeCancellable?.cancel()
        thermalChangeCancellable?.cancel()
    }

    func refreshNow() {
        refresh(reason: .manual)
    }

    private func bindSettings() {
        refreshIntervalCancellable = settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] interval in
                self?.scheduleTimer(using: interval)
            }
    }

    private func bindBatteryChanges() {
        batteryChangeCancellable = batteryCollector.stateDidChangePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.refresh(reason: .batteryNotification)
            }
    }

    private func bindThermalChanges() {
        thermalChangeCancellable = thermalCollector.stateDidChangePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh(reason: .thermalNotification)
            }
    }

    private func scheduleTimer(using interval: RefreshInterval) {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: interval.seconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh(reason: .interval)
            }
    }

    private func refresh(reason: RefreshReason) {
        let memory = memoryCollector.collect() ?? .empty(totalBytes: ProcessInfo.processInfo.physicalMemory)
        let storage = storageCollector.collect() ?? .empty()
        let battery = batteryCollector.collect() ?? .unavailable
        let thermal = thermalCollector.collect()
        let cpu = cpuCollector.collect()
        let network = networkCollector.collect()
        let gpu = gpuCollector.collect()

        latestSnapshot = SystemSnapshot(
            timestamp: now(),
            memory: memory,
            storage: storage,
            battery: battery,
            thermal: thermal,
            cpu: cpu,
            network: network,
            gpu: gpu,
            refreshReason: reason
        )
    }
}
