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

    // MARK: - parse

    func testParse_numericPredicate() {
        let p = ProcessFilter.parse("cpu > 50")
        XCTAssertEqual(p?.field, .cpu)
        XCTAssertEqual(p?.op, .gt)
        XCTAssertEqual(p?.value, "50")
        XCTAssertEqual(ProcessFilter.apply(records, p!).map(\.pid), [1])
    }

    func testParse_multiCharOperatorBeatsPrefix() {
        // ">=" must win over ">", else value becomes "= 90".
        let p = ProcessFilter.parse("cpu >= 90")
        XCTAssertEqual(p?.op, .ge)
        XCTAssertEqual(p?.value, "90")
    }

    func testParse_memAliasAndNoSpaces() {
        let p = ProcessFilter.parse("mem>=1073741824")
        XCTAssertEqual(p?.field, .memory)
        XCTAssertEqual(p?.op, .ge)
        XCTAssertEqual(ProcessFilter.apply(records, p!).map(\.pid), [1])
    }

    func testParse_bareTermIsNameContains() {
        let p = ProcessFilter.parse("find")
        XCTAssertEqual(p?.field, .name)
        XCTAssertEqual(p?.op, .contains)
        XCTAssertEqual(ProcessFilter.apply(records, p!).map(\.pid), [2])
    }

    func testParse_emptyAndUnknownField() {
        XCTAssertNil(ProcessFilter.parse("   "))
        XCTAssertNil(ProcessFilter.parse("bogus > 1"))
        XCTAssertNil(ProcessFilter.parse("cpu >"))   // missing value
    }
}
