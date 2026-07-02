import XCTest
@testable import Burrow

final class ReceiptLinkerTests: XCTestCase {
    func testParseInfo() {
        let out = """
        package-id: com.apple.pkg.XProtectPlistConfigData_10_15.16U4423
        version: 5338.1.1775522733
        volume: /
        location: /
        install-time: 1775838074
        """
        let r = ReceiptLinker.parseInfo(out)
        XCTAssertEqual(r?.packageID, "com.apple.pkg.XProtectPlistConfigData_10_15.16U4423")
        XCTAssertEqual(r?.version, "5338.1.1775522733")
        XCTAssertEqual(r?.location, "/")
        XCTAssertNil(ReceiptLinker.parseInfo("no package id here"))
    }

    func testMatching() {
        let ids = ["com.docker.docker", "com.apple.pkg.X", "io.foo.bar"]
        XCTAssertEqual(ReceiptLinker.matching(bundleID: "com.docker.docker", packageIDs: ids), ["com.docker.docker"])
        XCTAssertTrue(ReceiptLinker.matching(bundleID: "single", packageIDs: ids).isEmpty)
    }
}
