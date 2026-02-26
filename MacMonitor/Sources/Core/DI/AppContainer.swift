import Combine
import Foundation

@MainActor
final class AppContainer {
    private let settingsStore: SettingsStore
    private let appUpdateController: AppUpdateController
    private let metricsEngine: MetricsEngine
    private let snapshotStore: SnapshotStore
    private let appGroupSnapshotStore: AppGroupSnapshotStore
    private let diagnosticsExporter: DiagnosticsExporter
    private let summaryViewModel: SystemSummaryViewModel
    private let ramDetailsViewModel: RAMDetailsViewModel
    private let ramPolicyViewModel: RAMPolicySettingsViewModel
    private let storageManagementViewModel: StorageManagementViewModel
    private let ramPolicyMonitor: RAMPolicyMonitor
    private let batteryPolicyCoordinator: BatteryPolicyCoordinator
    private let batteryScheduleCoordinator: BatteryScheduleCoordinator
    private let batteryScheduleViewModel: BatteryScheduleViewModel
    private let batteryLifecycleCoordinator: BatteryLifecycleCoordinator
    private let menuBarController: MenuBarController
    private var batterySnapshotCancellable: AnyCancellable?
    private var storageSnapshotCancellable: AnyCancellable?

    init() {
        let settings = SettingsStore(launchAtLoginManager: LaunchAtLoginManager())
        let appUpdateController = AppUpdateController()
        let memoryCollector = MemoryCollector()
        let storageCollector = StorageCollector()
        let batteryCollector = BatteryCollector()
        let thermalCollector = ThermalCollector()
        let cpuCollector = CPUCollector()
        let networkCollector = NetworkCollector()
        let gpuCollector = DefaultGPUCollector()

        let engine = MetricsEngine(
            memoryCollector: memoryCollector,
            storageCollector: storageCollector,
            batteryCollector: batteryCollector,
            thermalCollector: thermalCollector,
            cpuCollector: cpuCollector,
            networkCollector: networkCollector,
            gpuCollector: gpuCollector,
            settings: settings
        )

        let store = SnapshotStore()
        let appGroupSnapshotStore = AppGroupSnapshotStore()
        let diagnosticsExporter = DiagnosticsExporter()
        let viewModel = SystemSummaryViewModel(
            engine: engine,
            snapshotStore: store,
            settings: settings,
            appGroupSnapshotStore: appGroupSnapshotStore
        )
        let storageManagementViewModel = StorageManagementViewModel(
            storageManager: LocalStorageManager(),
            runningAppPreflightCoordinator: RunningAppPreflightCoordinator()
        )
        let processProtectionPolicy = DefaultProcessProtectionPolicy()
        let processCollector = LibprocProcessListCollector(protectionPolicy: processProtectionPolicy)
        let listeningPortCollector = LsofListeningPortCollector(protectionPolicy: processProtectionPolicy)
        let processTerminator = SignalProcessTerminator()
        let ramDetails = RAMDetailsViewModel(
            processCollector: processCollector,
            processTerminator: processTerminator,
            listeningPortCollector: listeningPortCollector
        )
        let policyStore = FileRAMPolicyStore()
        let eventStore = FileRAMPolicyEventStore()
        let appRAMCollector = LibprocAppRAMCollector()
        let policyEvaluator = RAMPolicyEvaluator()
        let notifier = UserNotificationRAMPolicyNotifier()
        let policyMonitor = RAMPolicyMonitor(
            policyStore: policyStore,
            eventStore: eventStore,
            usageCollector: appRAMCollector,
            evaluator: policyEvaluator,
            notifier: notifier
        )
        let policyViewModel = RAMPolicySettingsViewModel(
            policyStore: policyStore,
            eventStore: eventStore,
            monitor: policyMonitor
        )

        let helperInstaller = SMJobBlessBatteryHelperInstaller()
        let backend: BatteryControlBackend = XPCBatteryControlBackend(helperInstaller: helperInstaller)

        let batteryEventStore = FileBatteryEventStore()
        let batteryControlService = BatteryControlService(
            backend: backend,
            eventStore: batteryEventStore
        )
        let batteryReconciliationManager = BatteryReconciliationManager(
            policyEngine: BatteryPolicyEngine(),
            controlService: batteryControlService
        )
        let batteryPolicyCoordinator = BatteryPolicyCoordinator(
            settings: settings,
            controlService: batteryControlService,
            reconciliationManager: batteryReconciliationManager
        )
        let batteryScheduleCoordinator = BatteryScheduleCoordinator(
            store: FileBatteryScheduleStore(),
            queueEngine: BatteryScheduleEngine(),
            policyCoordinator: batteryPolicyCoordinator
        )
        let batteryScheduleViewModel = BatteryScheduleViewModel(
            scheduleCoordinator: batteryScheduleCoordinator,
            policyCoordinator: batteryPolicyCoordinator
        )
        let batteryLifecycleCoordinator = BatteryLifecycleCoordinator { [weak batteryPolicyCoordinator, weak batteryScheduleCoordinator] event in
            Task { @MainActor [weak batteryPolicyCoordinator, weak batteryScheduleCoordinator] in
                await batteryPolicyCoordinator?.handleLifecycleEvent(event)
                if event == .didWake || event == .userSessionDidBecomeActive {
                    batteryScheduleCoordinator?.processWakeCatchUp()
                }
            }
        }

        BatteryIntentBridge.shared.handler = { [weak batteryPolicyCoordinator] command in
            guard let batteryPolicyCoordinator else {
                return .failure("Battery control is not available.")
            }
            switch command {
            case .setChargeLimit(let limit):
                let result = await batteryPolicyCoordinator.setChargeLimit(limit)
                return result.accepted
                ? .success("Charge limit set to \(min(max(limit, 50), 95))%.")
                : .failure(result.message ?? "Failed to set charge limit.")
            case .pauseCharging:
                let result = await batteryPolicyCoordinator.pauseChargingNow()
                return result.accepted
                ? .success("Charging paused.")
                : .failure(result.message ?? "Failed to pause charging.")
            case .startTopUp:
                let result = await batteryPolicyCoordinator.startTopUpNow()
                return result.accepted
                ? .success("Top Up started.")
                : .failure(result.message ?? "Failed to start Top Up.")
            case .startDischarge(let target):
                let result = await batteryPolicyCoordinator.startDischargeNow(targetPercent: target)
                return result.accepted
                ? .success("Discharge started toward \(min(max(target, 50), 95))%.")
                : .failure(result.message ?? "Failed to start discharge.")
            case .getState:
                return .success(batteryPolicyCoordinator.statusText())
            }
        }

        let menuBar = MenuBarController(
            viewModel: viewModel,
            ramDetailsViewModel: ramDetails,
            ramPolicyViewModel: policyViewModel,
            storageManagementViewModel: storageManagementViewModel,
            batteryPolicyCoordinator: batteryPolicyCoordinator,
            batteryScheduleViewModel: batteryScheduleViewModel,
            appUpdateController: appUpdateController,
            diagnosticsExporter: diagnosticsExporter
        )

        self.settingsStore = settings
        self.appUpdateController = appUpdateController
        self.metricsEngine = engine
        self.snapshotStore = store
        self.appGroupSnapshotStore = appGroupSnapshotStore
        self.diagnosticsExporter = diagnosticsExporter
        self.summaryViewModel = viewModel
        self.ramDetailsViewModel = ramDetails
        self.ramPolicyViewModel = policyViewModel
        self.storageManagementViewModel = storageManagementViewModel
        self.ramPolicyMonitor = policyMonitor
        self.batteryPolicyCoordinator = batteryPolicyCoordinator
        self.batteryScheduleCoordinator = batteryScheduleCoordinator
        self.batteryScheduleViewModel = batteryScheduleViewModel
        self.batteryLifecycleCoordinator = batteryLifecycleCoordinator
        self.menuBarController = menuBar
    }

    func start() {
        menuBarController.install()
        batteryPolicyCoordinator.start()
        Task { [weak self] in
            await self?.batteryScheduleCoordinator.start()
        }
        batterySnapshotCancellable = metricsEngine.$latestSnapshot
            .compactMap { $0?.battery }
            .sink { [weak self] snapshot in
                Task { [weak self] in
                    await self?.batteryPolicyCoordinator.handle(snapshot: snapshot)
                }
            }
        summaryViewModel.start()
        if let storage = summaryViewModel.snapshot?.storage {
            storageManagementViewModel.updateDiskUsageSnapshot(
                StorageDiskUsage(usedBytes: storage.usedBytes, totalBytes: storage.totalBytes)
            )
        }
        storageSnapshotCancellable = summaryViewModel.$snapshot
            .compactMap { $0?.storage }
            .sink { [weak self] storage in
                self?.storageManagementViewModel.updateDiskUsageSnapshot(
                    StorageDiskUsage(usedBytes: storage.usedBytes, totalBytes: storage.totalBytes)
                )
            }
        ramPolicyMonitor.start()
        batteryLifecycleCoordinator.start()
    }

    func stop() {
        batteryLifecycleCoordinator.stop()
        storageSnapshotCancellable?.cancel()
        storageSnapshotCancellable = nil
        batterySnapshotCancellable?.cancel()
        batterySnapshotCancellable = nil
        batteryScheduleCoordinator.stop()
        batteryPolicyCoordinator.stop()
        summaryViewModel.stop()
        ramDetailsViewModel.stop()
        storageManagementViewModel.stop()
        ramPolicyMonitor.stop()
        menuBarController.uninstall()
    }
}
