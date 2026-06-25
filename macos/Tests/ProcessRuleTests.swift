import XCTest
@testable import Burrow

final class ProcessRuleTests: XCTestCase {
    private let rule = ProcessRule.Rule(metric: .cpu, threshold: 80, sustainSeconds: 3, action: .notify)

    func testFiresWhenSustainedOverThreshold() {
        XCTAssertTrue(ProcessRule.fires(rule, samples: [50, 90, 95, 100]))   // last 3 all > 80
    }

    func testDoesNotFireOnDip() {
        XCTAssertFalse(ProcessRule.fires(rule, samples: [90, 70, 95, 100]))  // last 3 include 70
    }

    func testDoesNotFireBeforeWindowFills() {
        XCTAssertFalse(ProcessRule.fires(rule, samples: [90, 95]))
    }
}
