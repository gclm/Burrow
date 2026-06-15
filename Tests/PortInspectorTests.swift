//
//  PortInspectorTests.swift
//  BurrowTests
//
//  Port-inspector safety + ordering (roadmap C.10).
//

import XCTest
@testable import Burrow

final class PortInspectorTests: XCTestCase {
    private func port(_ p: Int, _ name: String, uid: Int) -> ListeningPort {
        ListeningPort(pid: 1, process: name, port: p, proto: "tcp", address: "127.0.0.1", uid: uid)
    }

    func testKillable_onlyOwnNonRootProcesses() {
        XCTAssertTrue(PortInspector.isKillable(port(3000, "node", uid: 501), currentUID: 501))
        XCTAssertFalse(PortInspector.isKillable(port(22, "sshd", uid: 0), currentUID: 501),
                       "never offer to kill a root-owned daemon")
        XCTAssertFalse(PortInspector.isKillable(port(8080, "other", uid: 502), currentUID: 501),
                       "not another user's process")
    }

    func testSorted_byPortThenName_isStable() {
        let unsorted = [port(8080, "b", uid: 1), port(3000, "z", uid: 1), port(3000, "a", uid: 1)]
        let s = PortInspector.sorted(unsorted)
        XCTAssertEqual(s.map(\.port), [3000, 3000, 8080])
        XCTAssertEqual(s.map(\.process), ["a", "z", "b"])
    }
}
