//
//  OSUpdateGateTests.swift
//  BurrowTests
//

import XCTest
@testable import Burrow

final class OSUpdateGateTests: XCTestCase {
    func testInstallable_hiddenWhenOSTooOld() {
        XCTAssertFalse(OSUpdateGate.isInstallable(minimumOS: "26.0", running: "15.5"))
        XCTAssertTrue(OSUpdateGate.isInstallable(minimumOS: "15.0", running: "15.5"))
        XCTAssertTrue(OSUpdateGate.isInstallable(minimumOS: "15.5", running: "15.5"), "equal installs")
        XCTAssertTrue(OSUpdateGate.isInstallable(minimumOS: nil, running: "15.5"), "no requirement")
        XCTAssertTrue(OSUpdateGate.isInstallable(minimumOS: "", running: "15.5"))
    }

    func testRaggedVersions() {
        XCTAssertTrue(OSUpdateGate.isInstallable(minimumOS: "14", running: "14.5.1"))
        XCTAssertFalse(OSUpdateGate.isInstallable(minimumOS: "14.6", running: "14.5"))
        XCTAssertTrue(OSUpdateGate.isInstallable(minimumOS: "26", running: "26.5.1"))
    }

    func testUpdateLanded() {
        XCTAssertTrue(OSUpdateGate.updateLanded(offered: "2.0.0", onDisk: "2.0.0"))
        XCTAssertTrue(OSUpdateGate.updateLanded(offered: "2.0.0", onDisk: "2.1.0"))
        XCTAssertFalse(OSUpdateGate.updateLanded(offered: "2.0.0", onDisk: "1.9.9"))
    }
}
