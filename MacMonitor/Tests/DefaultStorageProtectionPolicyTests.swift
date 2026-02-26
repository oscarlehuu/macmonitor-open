import XCTest
@testable import MacMonitor

final class DefaultStorageProtectionPolicyTests: XCTestCase {
    func testProtectsCurrentApplicationPath() {
        let policy = DefaultStorageProtectionPolicy(currentApplicationPath: "/Applications/MacMonitor.app")

        let decision = policy.evaluate(url: URL(fileURLWithPath: "/Applications/MacMonitor.app/Contents/MacOS/MacMonitor"))

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .currentApplication)
    }

    func testProtectsSystemPathPrefix() {
        let policy = DefaultStorageProtectionPolicy(currentApplicationPath: "/Applications/MacMonitor.app")

        let decision = policy.evaluate(url: URL(fileURLWithPath: "/System/Applications/Utilities"))

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .systemPath)
    }

    func testAllowsUserCachePath() {
        let policy = DefaultStorageProtectionPolicy(currentApplicationPath: "/Applications/MacMonitor.app")
        let userCachePath = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
            .path

        let decision = policy.evaluate(url: URL(fileURLWithPath: userCachePath))

        XCTAssertFalse(decision.isProtected)
        XCTAssertNil(decision.reason)
    }
}
