import XCTest
@testable import Burrow

final class TreemapTailTests: XCTestCase {
    private let cells = [
        TreemapTail.Cell(name: "a", size: 100), TreemapTail.Cell(name: "b", size: 50),
        TreemapTail.Cell(name: "c", size: 10), TreemapTail.Cell(name: "d", size: 5),
    ]

    func testFoldsTailAndPreservesTotal() {
        let folded = TreemapTail.fold(cells, keep: 2)
        XCTAssertEqual(folded.map(\.name), ["a", "b", "Other"])
        XCTAssertEqual(folded.last?.size, 15)                              // 10 + 5
        XCTAssertEqual(folded.reduce(Int64(0)) { $0 + $1.size }, 165)       // total preserved
    }

    func testNothingToFold() {
        XCTAssertEqual(TreemapTail.fold(cells, keep: 10).count, 4)
    }
}
