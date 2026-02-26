import XCTest
@testable import MacMonitor

final class MetricFormatterTests: XCTestCase {
    func testPercentFormatting() {
        XCTAssertEqual(MetricFormatter.percent(used: 50, total: 100), "50%")
    }

    func testUsageFormattingContainsSeparator() {
        let value = MetricFormatter.usage(used: 1_000_000_000, total: 2_000_000_000)
        XCTAssertTrue(value.contains("/"))
    }

    func testThermalText() {
        XCTAssertEqual(MetricFormatter.thermalText(for: .serious), "Serious")
    }
}
