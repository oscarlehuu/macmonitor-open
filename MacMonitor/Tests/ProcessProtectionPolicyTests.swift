import XCTest
@testable import MacMonitor

final class ProcessProtectionPolicyTests: XCTestCase {
    func testProtectsCurrentApplicationProcess() {
        let policy = DefaultProcessProtectionPolicy(currentProcessID: 42, currentUserID: 501)

        let decision = policy.evaluate(processID: 42, userID: 501, flags: 0, processName: "MacMonitor")

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .currentApplication)
    }

    func testProtectsReservedPID() {
        let policy = DefaultProcessProtectionPolicy(currentProcessID: 42, currentUserID: 501)

        let decision = policy.evaluate(processID: 1, userID: 0, flags: 0, processName: "launchd")

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .kernelReserved)
    }

    func testProtectsSystemFlaggedProcess() {
        let policy = DefaultProcessProtectionPolicy(currentProcessID: 42, currentUserID: 501)

        let decision = policy.evaluate(
            processID: 100,
            userID: 501,
            flags: UInt32(PROC_FLAG_SYSTEM),
            processName: "SomeSystemTask"
        )

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .systemProcess)
    }

    func testProtectsDifferentUserProcess() {
        let policy = DefaultProcessProtectionPolicy(currentProcessID: 42, currentUserID: 501)

        let decision = policy.evaluate(processID: 100, userID: 0, flags: 0, processName: "root-daemon")

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .differentOwner)
    }

    func testProtectsCriticalProcessNameCaseInsensitively() {
        let policy = DefaultProcessProtectionPolicy(currentProcessID: 42, currentUserID: 501)

        let decision = policy.evaluate(processID: 100, userID: 501, flags: 0, processName: "WindowServer")

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .criticalName)
    }

    func testAllowsRegularUserProcess() {
        let policy = DefaultProcessProtectionPolicy(currentProcessID: 42, currentUserID: 501)

        let decision = policy.evaluate(processID: 100, userID: 501, flags: 0, processName: "Notes")

        XCTAssertFalse(decision.isProtected)
        XCTAssertNil(decision.reason)
    }
}
