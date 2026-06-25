import XCTest
@testable import Burrow

final class ElectronVersionResolverTests: XCTestCase {
    func testParsesVersionOrName() {
        XCTAssertEqual(ElectronVersionResolver.version(fromFeed: #"{"url":"x","version":"1.2.3"}"#), "1.2.3")
        XCTAssertEqual(ElectronVersionResolver.version(fromFeed: #"{"name":"v2.0.0"}"#), "2.0.0")
        XCTAssertNil(ElectronVersionResolver.version(fromFeed: "not json"))
    }

    func testNewer() {
        XCTAssertEqual(ElectronVersionResolver.newerVersion(feed: #"{"version":"1.2.3"}"#, installed: "1.2.0"), "1.2.3")
        XCTAssertNil(ElectronVersionResolver.newerVersion(feed: #"{"version":"1.2.3"}"#, installed: "1.2.3"))
    }
}
