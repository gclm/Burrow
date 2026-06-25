import XCTest
@testable import Burrow

final class ProcessFilterTests: XCTestCase {
    private let records = [
        ProcessFilter.Record(pid: 1, name: "node", cpu: 90, memBytes: 1 << 30, threads: 10),
        ProcessFilter.Record(pid: 2, name: "Finder", cpu: 1, memBytes: 1 << 20, threads: 3),
    ]

    func testNumericGreater() {
        let p = ProcessFilter.Predicate(field: .cpu, op: .gt, value: "50")
        XCTAssertEqual(ProcessFilter.apply(records, p).map(\.pid), [1])
    }

    func testNameContains() {
        let p = ProcessFilter.Predicate(field: .name, op: .contains, value: "find")
        XCTAssertEqual(ProcessFilter.apply(records, p).map(\.pid), [2])
    }

    func testMemoryAtLeast() {
        let p = ProcessFilter.Predicate(field: .memory, op: .ge, value: "\(1 << 30)")
        XCTAssertEqual(ProcessFilter.apply(records, p).map(\.pid), [1])
    }
}
