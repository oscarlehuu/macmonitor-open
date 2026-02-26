import XCTest
@testable import MacMonitor

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testPersistsRefreshInterval() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.refreshInterval = .fiveMinutes

        XCTAssertEqual(defaults.integer(forKey: "settings.refreshIntervalMinutes"), 5)
    }

    func testLaunchAtLoginFailureRevertsToggleAndStoresError() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager(enabled: false, throwOnSet: true)
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.launchAtLoginEnabled = true

        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertNotNil(store.launchAtLoginError)
    }

    func testPersistsMenuBarDisplaySettings() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.menuBarDisplayMode = .both
        store.menuBarMemoryFormat = .numberUsage
        store.menuBarStorageFormat = .numberLeft

        XCTAssertEqual(defaults.string(forKey: "settings.menuBarDisplayMode"), "both")
        XCTAssertEqual(defaults.string(forKey: "settings.menuBarMemoryFormat"), "numberUsage")
        XCTAssertEqual(defaults.string(forKey: "settings.menuBarStorageFormat"), "numberLeft")
    }

    func testHydratesPersistedMenuBarDisplaySettings() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        defaults.set("storage", forKey: "settings.menuBarDisplayMode")
        defaults.set("numberUsage", forKey: "settings.menuBarMemoryFormat")
        defaults.set("percentUsage", forKey: "settings.menuBarStorageFormat")
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.menuBarDisplayMode, .storage)
        XCTAssertEqual(store.menuBarMemoryFormat, .numberUsage)
        XCTAssertEqual(store.menuBarStorageFormat, .percentUsage)
    }

    func testMigratesLegacyMenuBarFormatSettings() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        defaults.set("ram", forKey: "settings.menuBarDisplayMode")
        defaults.set("free", forKey: "settings.menuBarMetricValueMode")
        defaults.set("number", forKey: "settings.menuBarMetricFormat")
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.menuBarDisplayMode, .memory)
        XCTAssertEqual(store.menuBarMemoryFormat, .numberLeft)
        XCTAssertEqual(store.menuBarStorageFormat, .numberLeft)
    }

    func testPersistsBatteryPolicyConfiguration() throws {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 83
        config.automaticDischargeEnabled = true
        store.batteryPolicyConfiguration = config

        let persistedData = try XCTUnwrap(defaults.data(forKey: "settings.batteryPolicyConfiguration"))
        let persistedConfig = try JSONDecoder().decode(BatteryPolicyConfiguration.self, from: persistedData)

        XCTAssertEqual(persistedConfig.chargeLimitPercent, 83)
        XCTAssertTrue(persistedConfig.automaticDischargeEnabled)
    }

    func testNormalizesBatteryPolicyConfigurationBounds() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 20
        config.sailingLowerPercent = 99
        config.sailingUpperPercent = 40
        config.heatProtectionThresholdCelsius = 90

        store.batteryPolicyConfiguration = config

        XCTAssertEqual(store.batteryPolicyConfiguration.chargeLimitPercent, 50)
        XCTAssertEqual(store.batteryPolicyConfiguration.sailingLowerPercent, 50)
        XCTAssertEqual(store.batteryPolicyConfiguration.sailingUpperPercent, 95)
        XCTAssertEqual(store.batteryPolicyConfiguration.heatProtectionThresholdCelsius, 55)
    }

    func testNormalizesBatteryPolicyConfigurationDischargeMutualExclusion() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var config = BatteryPolicyConfiguration.default
        config.manualDischargeEnabled = true
        config.automaticDischargeEnabled = true

        store.batteryPolicyConfiguration = config

        XCTAssertTrue(store.batteryPolicyConfiguration.manualDischargeEnabled)
        XCTAssertFalse(store.batteryPolicyConfiguration.automaticDischargeEnabled)
    }
}

private final class MutableLaunchManager: LaunchAtLoginManaging {
    private(set) var enabled: Bool
    private let throwOnSet: Bool

    init(enabled: Bool = false, throwOnSet: Bool = false) {
        self.enabled = enabled
        self.throwOnSet = throwOnSet
    }

    func isEnabled() -> Bool {
        enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if throwOnSet {
            throw TestError.toggleFailed
        }
        self.enabled = enabled
    }
}

private enum TestError: Error {
    case toggleFailed
}
