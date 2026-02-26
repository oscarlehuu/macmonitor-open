import Combine
import Foundation

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case lime
    case midnight
    case cyber
    case daylight
    case arctic
    case sand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lime: return "Dark"
        case .midnight: return "Midnight"
        case .cyber: return "Cyberpunk"
        case .daylight: return "Light"
        case .arctic: return "Arctic"
        case .sand: return "Sand"
        }
    }

    var isDark: Bool {
        switch self {
        case .lime, .midnight, .cyber: return true
        case .daylight, .arctic, .sand: return false
        }
    }

    var symbol: String {
        isDark ? "moon.fill" : "sun.max.fill"
    }
}

// MARK: - Settings Enums

enum RefreshInterval: Int, CaseIterable, Codable, Identifiable {
    case oneMinute = 1
    case threeMinutes = 3
    case fiveMinutes = 5
    case tenMinutes = 10

    var id: Int { rawValue }

    var title: String {
        "Every \(rawValue) min"
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Codable, Identifiable {
    case memory
    case storage
    case cpu
    case network
    case both
    case icon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memory:
            return "Memory"
        case .storage:
            return "Storage"
        case .cpu:
            return "CPU"
        case .network:
            return "Network"
        case .both:
            return "Both"
        case .icon:
            return "Icon Only"
        }
    }
}

enum MenuBarMetricDisplayFormat: String, CaseIterable, Codable, Identifiable {
    case percentUsage
    case numberUsage
    case numberLeft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentUsage:
            return "% Usage"
        case .numberUsage:
            return "Number (Usage)"
        case .numberLeft:
            return "Number (Left)"
        }
    }
}

struct SystemAlertSettings: Codable, Equatable {
    var thermalAlertEnabled: Bool
    var thermalThreshold: ThermalState
    var storageAlertEnabled: Bool
    var storageUsagePercentThreshold: Int
    var batteryHealthDropAlertEnabled: Bool
    var batteryHealthDropPercentThreshold: Int
    var cooldownMinutes: Int

    static let `default` = SystemAlertSettings(
        thermalAlertEnabled: true,
        thermalThreshold: .serious,
        storageAlertEnabled: true,
        storageUsagePercentThreshold: 90,
        batteryHealthDropAlertEnabled: true,
        batteryHealthDropPercentThreshold: 15,
        cooldownMinutes: 45
    )

    func normalized() -> SystemAlertSettings {
        let normalizedThreshold: ThermalState
        switch thermalThreshold {
        case .nominal, .fair, .serious, .critical:
            normalizedThreshold = thermalThreshold
        case .unknown:
            normalizedThreshold = .serious
        }

        return SystemAlertSettings(
            thermalAlertEnabled: thermalAlertEnabled,
            thermalThreshold: normalizedThreshold,
            storageAlertEnabled: storageAlertEnabled,
            storageUsagePercentThreshold: min(max(storageUsagePercentThreshold, 60), 99),
            batteryHealthDropAlertEnabled: batteryHealthDropAlertEnabled,
            batteryHealthDropPercentThreshold: min(max(batteryHealthDropPercentThreshold, 5), 40),
            cooldownMinutes: min(max(cooldownMinutes, 5), 360)
        )
    }
}

struct BatteryAdvancedControlFeatureFlags: Codable, Equatable {
    var sleepAwareStopChargingEnabled: Bool
    var blockSleepUntilLimitEnabled: Bool
    var calibrationWorkflowEnabled: Bool
    var hardwarePercentageRefinementEnabled: Bool
    var magsafeLEDControlEnabled: Bool

    static let `default` = BatteryAdvancedControlFeatureFlags(
        sleepAwareStopChargingEnabled: false,
        blockSleepUntilLimitEnabled: false,
        calibrationWorkflowEnabled: false,
        hardwarePercentageRefinementEnabled: false,
        magsafeLEDControlEnabled: false
    )

    var anyEnabled: Bool {
        sleepAwareStopChargingEnabled
            || blockSleepUntilLimitEnabled
            || calibrationWorkflowEnabled
            || hardwarePercentageRefinementEnabled
            || magsafeLEDControlEnabled
    }
}

protocol LaunchAtLoginManaging {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var appTheme: AppTheme {
        didSet {
            guard !isHydrating else { return }
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
            PopoverTheme.applyTheme(appTheme)
        }
    }

    @Published var refreshInterval: RefreshInterval {
        didSet {
            guard !isHydrating else { return }
            defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
        }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            guard !isHydrating else { return }
            defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode)
        }
    }

    @Published var menuBarMemoryFormat: MenuBarMetricDisplayFormat {
        didSet {
            guard !isHydrating else { return }
            defaults.set(menuBarMemoryFormat.rawValue, forKey: Keys.menuBarMemoryFormat)
        }
    }

    @Published var menuBarStorageFormat: MenuBarMetricDisplayFormat {
        didSet {
            guard !isHydrating else { return }
            defaults.set(menuBarStorageFormat.rawValue, forKey: Keys.menuBarStorageFormat)
        }
    }

    @Published var batteryPolicyConfiguration: BatteryPolicyConfiguration {
        didSet {
            guard !isHydrating else { return }
            let normalized = batteryPolicyConfiguration.normalized()
            if normalized != batteryPolicyConfiguration {
                batteryPolicyConfiguration = normalized
                return
            }
            persistBatteryPolicyConfiguration(normalized)
        }
    }

    @Published var systemAlertSettings: SystemAlertSettings {
        didSet {
            guard !isHydrating else { return }
            let normalized = systemAlertSettings.normalized()
            if normalized != systemAlertSettings {
                systemAlertSettings = normalized
                return
            }
            persistSystemAlertSettings(normalized)
        }
    }

    @Published var batteryAdvancedControlFeatureFlags: BatteryAdvancedControlFeatureFlags {
        didSet {
            guard !isHydrating else { return }
            persistBatteryAdvancedControlFeatureFlags(batteryAdvancedControlFeatureFlags)
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            guard !isHydrating, !isSyncingLaunchToggle else { return }
            defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLogin)
            applyLaunchAtLoginToggle()
        }
    }

    @Published private(set) var launchAtLoginError: String?

    private let defaults: UserDefaults
    private let launchAtLoginManager: LaunchAtLoginManaging
    private var isHydrating = true
    private var isSyncingLaunchToggle = false

    private enum Keys {
        static let appTheme = "settings.appTheme"
        static let refreshInterval = "settings.refreshIntervalMinutes"
        static let menuBarDisplayMode = "settings.menuBarDisplayMode"
        static let menuBarMemoryFormat = "settings.menuBarMemoryFormat"
        static let menuBarStorageFormat = "settings.menuBarStorageFormat"

        // Legacy keys kept for migration.
        static let legacyMenuBarDisplayMode = "settings.menuBarDisplayMode"
        static let legacyMenuBarMetricValueMode = "settings.menuBarMetricValueMode"
        static let legacyMenuBarMetricFormat = "settings.menuBarMetricFormat"
        static let batteryPolicyConfiguration = "settings.batteryPolicyConfiguration"
        static let systemAlertSettings = "settings.systemAlertSettings"
        static let batteryAdvancedControlFeatureFlags = "settings.batteryAdvancedControlFeatureFlags"
        static let launchAtLogin = "settings.launchAtLogin"
    }

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginManager: LaunchAtLoginManaging
    ) {
        self.defaults = defaults
        self.launchAtLoginManager = launchAtLoginManager

        self.appTheme = AppTheme(
            rawValue: defaults.string(forKey: Keys.appTheme) ?? ""
        ) ?? .lime

        let persistedInterval = defaults.integer(forKey: Keys.refreshInterval)
        self.refreshInterval = RefreshInterval(rawValue: persistedInterval) ?? .threeMinutes

        self.menuBarDisplayMode = Self.loadMenuBarDisplayMode(defaults: defaults)
        self.menuBarMemoryFormat = Self.loadMenuBarMetricFormat(
            defaults: defaults,
            key: Keys.menuBarMemoryFormat,
            defaultFormat: .percentUsage
        )
        self.menuBarStorageFormat = Self.loadMenuBarMetricFormat(
            defaults: defaults,
            key: Keys.menuBarStorageFormat,
            defaultFormat: .numberLeft
        )

        self.batteryPolicyConfiguration = Self.loadBatteryPolicyConfiguration(defaults: defaults)
        self.systemAlertSettings = Self.loadSystemAlertSettings(defaults: defaults)
        self.batteryAdvancedControlFeatureFlags = Self.loadBatteryAdvancedControlFeatureFlags(defaults: defaults)

        if defaults.object(forKey: Keys.launchAtLogin) == nil {
            self.launchAtLoginEnabled = launchAtLoginManager.isEnabled()
        } else {
            self.launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLogin)
        }

        isHydrating = false
        PopoverTheme.applyTheme(appTheme)
    }

    private static func loadBatteryPolicyConfiguration(defaults: UserDefaults) -> BatteryPolicyConfiguration {
        guard let data = defaults.data(forKey: Keys.batteryPolicyConfiguration) else {
            return .default
        }
        guard let decoded = try? JSONDecoder().decode(BatteryPolicyConfiguration.self, from: data) else {
            return .default
        }
        return decoded.normalized()
    }

    private static func loadSystemAlertSettings(defaults: UserDefaults) -> SystemAlertSettings {
        guard let data = defaults.data(forKey: Keys.systemAlertSettings),
              let decoded = try? JSONDecoder().decode(SystemAlertSettings.self, from: data) else {
            return .default
        }
        return decoded.normalized()
    }

    private static func loadBatteryAdvancedControlFeatureFlags(defaults: UserDefaults) -> BatteryAdvancedControlFeatureFlags {
        guard let data = defaults.data(forKey: Keys.batteryAdvancedControlFeatureFlags),
              let decoded = try? JSONDecoder().decode(BatteryAdvancedControlFeatureFlags.self, from: data) else {
            return .default
        }
        return decoded
    }

    private static func loadMenuBarDisplayMode(defaults: UserDefaults) -> MenuBarDisplayMode {
        if let persisted = defaults.string(forKey: Keys.menuBarDisplayMode),
           let mode = MenuBarDisplayMode(rawValue: persisted) {
            return mode
        }

        if let legacyMode = defaults.string(forKey: Keys.legacyMenuBarDisplayMode) {
            switch legacyMode {
            case "ram":
                return .memory
            case "storage":
                return .storage
            case "icon":
                return .icon
            case "battery":
                return .memory
            case "both":
                return .both
            default:
                break
            }
        }

        return .memory
    }

    private static func loadMenuBarMetricFormat(
        defaults: UserDefaults,
        key: String,
        defaultFormat: MenuBarMetricDisplayFormat
    ) -> MenuBarMetricDisplayFormat {
        if let persisted = defaults.string(forKey: key),
           let format = MenuBarMetricDisplayFormat(rawValue: persisted) {
            return format
        }

        let legacyValueMode = defaults.string(forKey: Keys.legacyMenuBarMetricValueMode)
        let legacyFormat = defaults.string(forKey: Keys.legacyMenuBarMetricFormat)
        switch (legacyValueMode, legacyFormat) {
        case ("free", "number"):
            return .numberLeft
        case ("used", "number"):
            return .numberUsage
        case (_, "percent"):
            return .percentUsage
        default:
            return defaultFormat
        }
    }

    private func persistBatteryPolicyConfiguration(_ configuration: BatteryPolicyConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: Keys.batteryPolicyConfiguration)
    }

    private func persistSystemAlertSettings(_ configuration: SystemAlertSettings) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: Keys.systemAlertSettings)
    }

    private func persistBatteryAdvancedControlFeatureFlags(_ configuration: BatteryAdvancedControlFeatureFlags) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: Keys.batteryAdvancedControlFeatureFlags)
    }

    private func applyLaunchAtLoginToggle() {
        do {
            try launchAtLoginManager.setEnabled(launchAtLoginEnabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            isSyncingLaunchToggle = true
            launchAtLoginEnabled = launchAtLoginManager.isEnabled()
            isSyncingLaunchToggle = false
        }
    }
}
