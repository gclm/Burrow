import XCTest
@testable import Burrow

final class ProcessDeepMetricsTests: XCTestCase {
    func testUserFraction_split() {
        XCTAssertEqual(ProcessDeepMetrics.userFraction(userSeconds: 3, systemSeconds: 1), 0.75)
    }

    func testUserFraction_allUser() {
        XCTAssertEqual(ProcessDeepMetrics.userFraction(userSeconds: 2, systemSeconds: 0), 1.0)
    }

    func testUserFraction_noCPUYetIsNil() {
        XCTAssertNil(ProcessDeepMetrics.userFraction(userSeconds: 0, systemSeconds: 0))
    }
}
