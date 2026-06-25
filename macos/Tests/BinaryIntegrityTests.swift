import XCTest
@testable import Burrow

final class BinaryIntegrityTests: XCTestCase {
    func testVerdicts() {
        XCTAssertEqual(BinaryIntegrity.classify(launchInode: 42, onDiskInode: 42), .intact)
        XCTAssertEqual(BinaryIntegrity.classify(launchInode: 42, onDiskInode: 99), .replaced)
        XCTAssertEqual(BinaryIntegrity.classify(launchInode: 42, onDiskInode: nil), .deleted)
    }
}
