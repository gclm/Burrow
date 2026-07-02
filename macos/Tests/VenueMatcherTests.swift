import XCTest
@testable import Burrow

final class VenueMatcherTests: XCTestCase {
    func testMatchesKnownVenues() {
        XCTAssertEqual(VenueMatcher.match(ssid: "Hilton Honors Lobby")?.name, "Hilton")
        XCTAssertEqual(VenueMatcher.match(ssid: "Delta Fly-Fi")?.name, "Delta Fly-Fi")
        XCTAssertEqual(VenueMatcher.match(ssid: "JetBlue Fly-Fi")?.name, "JetBlue Fly-Fi")
    }

    func testUnknownAndTipsPresent() {
        XCTAssertNil(VenueMatcher.match(ssid: "Joe's Coffee"))
        XCTAssertFalse(VenueMatcher.match(ssid: "Hilton")?.tips.isEmpty ?? true)
    }
}
