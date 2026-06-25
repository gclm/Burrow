import XCTest
@testable import Burrow

final class ConnectionFailureClassifierTests: XCTestCase {
    func testAllVerdicts() {
        XCTAssertEqual(ConnectionFailureClassifier.classify(online: true, portal: false, loginReachable: false), .ok)
        XCTAssertEqual(ConnectionFailureClassifier.classify(online: false, portal: true, loginReachable: true), .captivePortal)
        XCTAssertEqual(ConnectionFailureClassifier.classify(online: false, portal: true, loginReachable: false), .loginUnreachable)
        XCTAssertEqual(ConnectionFailureClassifier.classify(online: false, portal: false, loginReachable: false), .noInternet)
    }
}
