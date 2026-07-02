import XCTest
@testable import Burrow

final class ProcessExportTests: XCTestCase {
    func testCSVEscapes() {
        let rows = [ProcessExport.Row(pid: 1, name: "launchd", cpu: 0.5, memBytes: 1024, threads: 2),
                    ProcessExport.Row(pid: 2, name: "a,b", cpu: 1, memBytes: 2048, threads: 3)]
        let csv = ProcessExport.csv(rows)
        XCTAssertTrue(csv.hasPrefix("pid,name,cpu,memoryBytes,threads\n"))
        XCTAssertTrue(csv.contains("1,launchd,0.5,1024,2"))
        XCTAssertTrue(csv.contains("\"a,b\""))
    }

    func testJSON() {
        let json = ProcessExport.json([ProcessExport.Row(pid: 1, name: "x", cpu: 0, memBytes: 10, threads: 1)])
        XCTAssertTrue(json.contains("\"pid\":1"))
        XCTAssertTrue(json.contains("\"memoryBytes\":10"))
    }
}
