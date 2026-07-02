import XCTest
@testable import Burrow

final class OptimizeGuardsTests: XCTestCase {
    func testClearWhenNothingActive() {
        XCTAssertTrue(OptimizeGuards.warnings(OptimizeGuards.State()).isEmpty)
    }

    func testWarnsPerActiveCondition() {
        var s = OptimizeGuards.State()
        s.vpnActive = true
        s.btInput = true
        XCTAssertEqual(OptimizeGuards.warnings(s).count, 2)
    }
}
