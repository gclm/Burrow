import XCTest
@testable import Burrow

final class ProcessTreeTests: XCTestCase {
    func testBuildAndAggregate() {
        let procs = [
            ProcessTree.Proc(pid: 1, ppid: 0, cpu: 0, mem: 0, threads: 1),
            ProcessTree.Proc(pid: 2, ppid: 1, cpu: 10, mem: 100, threads: 2),
            ProcessTree.Proc(pid: 3, ppid: 2, cpu: 5, mem: 50, threads: 1),
        ]
        let roots = ProcessTree.build(procs)
        XCTAssertEqual(roots.count, 1)           // pid 1: ppid 0 not present → root
        let root = roots[0]
        XCTAssertEqual(root.proc.pid, 1)
        XCTAssertEqual(root.totalCPU, 15)         // 0 + 10 + 5
        XCTAssertEqual(root.totalMem, 150)
        XCTAssertEqual(root.totalThreads, 4)
        XCTAssertEqual(root.children.count, 1)
        XCTAssertEqual(root.children[0].children.count, 1)
    }
}
