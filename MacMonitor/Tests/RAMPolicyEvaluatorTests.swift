import XCTest
@testable import MacMonitor

final class RAMPolicyEvaluatorTests: XCTestCase {
    func testImmediateTriggerRespectsCooldown() {
        let evaluator = RAMPolicyEvaluator()
        let policy = makePolicy(triggerMode: .immediate, cooldownSeconds: 300)
        let usage = AppRAMUsage(bundleID: "com.test.cursor", displayName: "Cursor", usedBytes: 8 * 1024 * 1024 * 1024)

        let t0 = Date(timeIntervalSince1970: 1_000)
        let first = evaluator.evaluate(
            policies: [policy],
            usageByBundleID: [usage.bundleID: usage],
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            now: t0
        )

        let second = evaluator.evaluate(
            policies: [policy],
            usageByBundleID: [usage.bundleID: usage],
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            now: t0.addingTimeInterval(120)
        )

        let third = evaluator.evaluate(
            policies: [policy],
            usageByBundleID: [usage.bundleID: usage],
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            now: t0.addingTimeInterval(301)
        )

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first.first?.triggerKind, .immediate)
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(third.count, 1)
        XCTAssertEqual(third.first?.triggerKind, .immediate)
    }

    func testSustainedTriggerFiresOnlyAfterWindow() {
        let evaluator = RAMPolicyEvaluator()
        let policy = makePolicy(triggerMode: .sustained, sustainedSeconds: 10, cooldownSeconds: 0)
        let usage = AppRAMUsage(bundleID: "com.test.cursor", displayName: "Cursor", usedBytes: 8 * 1024 * 1024 * 1024)

        let t0 = Date(timeIntervalSince1970: 2_000)
        let first = evaluator.evaluate(
            policies: [policy],
            usageByBundleID: [usage.bundleID: usage],
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            now: t0
        )
        let second = evaluator.evaluate(
            policies: [policy],
            usageByBundleID: [usage.bundleID: usage],
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            now: t0.addingTimeInterval(9)
        )
        let third = evaluator.evaluate(
            policies: [policy],
            usageByBundleID: [usage.bundleID: usage],
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            now: t0.addingTimeInterval(10)
        )

        XCTAssertTrue(first.isEmpty)
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(third.count, 1)
        XCTAssertEqual(third.first?.triggerKind, .sustained)
    }

    func testBothModeTransitionsFromImmediateToSustained() {
        let evaluator = RAMPolicyEvaluator()
        let policy = makePolicy(triggerMode: .both, sustainedSeconds: 15, cooldownSeconds: 300)
        let usage = AppRAMUsage(bundleID: "com.test.cursor", displayName: "Cursor", usedBytes: 8 * 1024 * 1024 * 1024)

        let t0 = Date(timeIntervalSince1970: 3_000)
        let first = evaluator.evaluate(
            policies: [policy],
            usageByBundleID: [usage.bundleID: usage],
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            now: t0
        )

        let second = evaluator.evaluate(
            policies: [policy],
            usageByBundleID: [usage.bundleID: usage],
            totalMemoryBytes: 64 * 1024 * 1024 * 1024,
            now: t0.addingTimeInterval(16)
        )

        XCTAssertEqual(first.first?.triggerKind, .immediate)
        XCTAssertEqual(second.first?.triggerKind, .sustained)
    }

    private func makePolicy(
        triggerMode: RAMPolicyTriggerMode,
        sustainedSeconds: Int = RAMPolicy.defaultSustainedSeconds,
        cooldownSeconds: Int = RAMPolicy.defaultCooldownSeconds
    ) -> RAMPolicy {
        RAMPolicy(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            bundleID: "com.test.cursor",
            displayName: "Cursor",
            limitMode: .percent,
            limitValue: 10,
            triggerMode: triggerMode,
            sustainedSeconds: sustainedSeconds,
            notifyCooldownSeconds: cooldownSeconds,
            enabled: true,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}
