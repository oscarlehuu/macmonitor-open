import XCTest
@testable import MacMonitor

final class LsofListeningPortCollectorTests: XCTestCase {
    func testCollectListeningPortsParsesRowsAndAppliesProtectionPolicy() throws {
        let output = """
        p123
        cnode
        u501
        Loscar
        n127.0.0.1:3000
        n*:3001
        p1
        claunchd
        u0
        Lroot
        n*:53
        p345
        cpostgres
        u0
        Lroot
        n*:5432
        """

        let policy = DefaultProcessProtectionPolicy(
            currentProcessID: 999,
            currentUserID: 501,
            criticalNames: ["launchd"]
        )
        let collector = LsofListeningPortCollector(
            protectionPolicy: policy,
            execute: { _, _ in (status: 0, output: output) }
        )

        let rows = try collector.collectListeningPorts()

        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows.map(\.port), [53, 3000, 3001, 5432])

        XCTAssertEqual(rows[1].pid, 123)
        XCTAssertEqual(rows[1].endpoint, "127.0.0.1:3000")
        XCTAssertNil(rows[1].protectionReason)

        XCTAssertEqual(rows[0].pid, 1)
        XCTAssertEqual(rows[0].protectionReason, .kernelReserved)

        XCTAssertEqual(rows[3].pid, 345)
        XCTAssertEqual(rows[3].protectionReason, .differentOwner)
    }

    func testCollectListeningPortsThrowsWhenCommandFails() {
        let collector = LsofListeningPortCollector(
            protectionPolicy: DefaultProcessProtectionPolicy(),
            execute: { _, _ in (status: 1, output: "") }
        )

        XCTAssertThrowsError(try collector.collectListeningPorts()) { error in
            XCTAssertEqual(error as? ListeningPortCollectionError, .commandFailed(status: 1))
        }
    }
}
