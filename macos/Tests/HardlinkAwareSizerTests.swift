import XCTest
@testable import Burrow

final class HardlinkAwareSizerTests: XCTestCase {
    func testCountsSharedInodeOnce() {
        let entries = [
            HardlinkAwareSizer.Entry(inode: 1, nlink: 2, size: 100),
            HardlinkAwareSizer.Entry(inode: 1, nlink: 2, size: 100),   // hardlink, same inode
            HardlinkAwareSizer.Entry(inode: 2, nlink: 1, size: 50),
        ]
        XCTAssertEqual(HardlinkAwareSizer.exclusiveBytes(entries), 150)   // 100 (once) + 50
    }
}
