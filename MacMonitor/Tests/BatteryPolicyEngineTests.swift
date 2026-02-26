import XCTest
@testable import MacMonitor

final class BatteryPolicyEngineTests: XCTestCase {
    private let engine = BatteryPolicyEngine()

    func testHeatProtectionWinsOverTopUpAndDischarge() {
        let snapshot = makeSnapshot(percent: 92, isCharging: true, temperatureCelsius: 42)
        var config = BatteryPolicyConfiguration.default
        config.heatProtectionEnabled = true
        config.heatProtectionThresholdCelsius = 40
        config.topUpEnabled = true
        config.manualDischargeEnabled = true

        let decision = engine.evaluate(snapshot: snapshot, configuration: config)

        XCTAssertEqual(decision.state, .heatProtection)
        XCTAssertEqual(decision.command, .setChargingPaused(true))
    }

    func testTopUpWinsOverManualAndAutomaticDischarge() {
        let snapshot = makeSnapshot(percent: 70, isCharging: false, temperatureCelsius: 30)
        var config = BatteryPolicyConfiguration.default
        config.topUpEnabled = true
        config.manualDischargeEnabled = true
        config.automaticDischargeEnabled = true

        let decision = engine.evaluate(snapshot: snapshot, configuration: config)

        XCTAssertEqual(decision.state, .topUp)
        XCTAssertEqual(decision.command, .startTopUp)
    }

    func testManualDischargeWinsOverAutomaticDischarge() {
        let snapshot = makeSnapshot(percent: 90, isCharging: false, temperatureCelsius: 30)
        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 80
        config.manualDischargeEnabled = true
        config.automaticDischargeEnabled = true

        let decision = engine.evaluate(snapshot: snapshot, configuration: config)

        XCTAssertEqual(decision.state, .dischargingToLimit)
        XCTAssertEqual(decision.command, .startDischarge(targetPercent: 80))
    }

    func testAutomaticDischargeTriggersWhenAboveLimit() {
        let snapshot = makeSnapshot(percent: 88, isCharging: false, temperatureCelsius: 30)
        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 80
        config.automaticDischargeEnabled = true

        let decision = engine.evaluate(snapshot: snapshot, configuration: config)

        XCTAssertEqual(decision.state, .dischargingToLimit)
        XCTAssertEqual(decision.command, .startDischarge(targetPercent: 80))
    }

    func testSailingModeDischargesAtUpperBound() {
        let snapshot = makeSnapshot(percent: 80, isCharging: false, temperatureCelsius: 30)
        var config = BatteryPolicyConfiguration.default
        config.sailingModeEnabled = true
        config.sailingLowerPercent = 75
        config.sailingUpperPercent = 80

        let decision = engine.evaluate(snapshot: snapshot, configuration: config)

        XCTAssertEqual(decision.state, .sailing)
        XCTAssertEqual(decision.command, .startDischarge(targetPercent: 75))
    }

    func testSailingModeChargesAtLowerBound() {
        let snapshot = makeSnapshot(percent: 75, isCharging: false, temperatureCelsius: 30)
        var config = BatteryPolicyConfiguration.default
        config.sailingModeEnabled = true
        config.sailingLowerPercent = 75
        config.sailingUpperPercent = 80

        let decision = engine.evaluate(snapshot: snapshot, configuration: config)

        XCTAssertEqual(decision.state, .chargingToLimit)
        XCTAssertEqual(decision.command, .setChargeLimit(80))
    }

    func testChargeLimiterChargesWhenBelowLimit() {
        let snapshot = makeSnapshot(percent: 62, isCharging: false, temperatureCelsius: 30)
        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 80

        let decision = engine.evaluate(snapshot: snapshot, configuration: config)

        XCTAssertEqual(decision.state, .chargingToLimit)
        XCTAssertEqual(decision.command, .setChargeLimit(80))
    }

    func testChargeLimiterPausesWhenAboveLimit() {
        let snapshot = makeSnapshot(percent: 85, isCharging: false, temperatureCelsius: 30)
        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 80

        let decision = engine.evaluate(snapshot: snapshot, configuration: config)

        XCTAssertEqual(decision.state, .pausedAtLimit)
        XCTAssertEqual(decision.command, .setChargingPaused(true))
    }

    func testConfigurationNormalizationClampsChargeLimitToValidatedBounds() {
        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 30

        let decision = engine.evaluate(
            snapshot: makeSnapshot(percent: 45, isCharging: false, temperatureCelsius: 30),
            configuration: config
        )

        XCTAssertEqual(decision.command, .setChargeLimit(50))
    }

    private func makeSnapshot(percent: Int, isCharging: Bool, temperatureCelsius: Int) -> BatterySnapshot {
        BatterySnapshot(
            currentCapacity: percent,
            maxCapacity: 100,
            isPresent: true,
            isCharging: isCharging,
            isCharged: percent >= 100,
            powerSource: isCharging ? .ac : .battery,
            timeToEmptyMinutes: nil,
            timeToFullChargeMinutes: nil,
            amperageMilliAmps: nil,
            voltageMilliVolts: nil,
            temperatureCelsius: temperatureCelsius,
            cycleCount: nil,
            health: nil,
            healthCondition: nil,
            lowPowerModeEnabled: false
        )
    }
}
