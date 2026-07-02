//
//  SecurityPostureTests.swift
//  BurrowTests
//
//  Real-fixture parser tests for the Doctor security-posture checks.
//

import XCTest
@testable import Burrow

final class SecurityPostureTests: XCTestCase {
    func testSIP() {
        XCTAssertEqual(SecurityPosture.sip("System Integrity Protection status: enabled."), .on)
        XCTAssertEqual(SecurityPosture.sip("System Integrity Protection status: disabled."), .off)
        XCTAssertEqual(SecurityPosture.sip("unexpected"), .unknown)
    }

    func testGatekeeper() {
        XCTAssertEqual(SecurityPosture.gatekeeper("assessments enabled\n"), .on)
        XCTAssertEqual(SecurityPosture.gatekeeper("assessments disabled\n"), .off)
        XCTAssertEqual(SecurityPosture.gatekeeper(""), .unknown)
    }

    func testFileVault() {
        XCTAssertEqual(SecurityPosture.fileVault("FileVault is On."), .on)
        XCTAssertEqual(SecurityPosture.fileVault("FileVault is Off."), .off)
        XCTAssertEqual(SecurityPosture.fileVault("Deferred enablement appears to be active"), .unknown)
    }

    func testFirewall() {
        XCTAssertEqual(SecurityPosture.firewall("Firewall is enabled. (State = 1)"), .on)
        XCTAssertEqual(SecurityPosture.firewall("Firewall is enabled. (State = 2)"), .on)   // block-all
        XCTAssertEqual(SecurityPosture.firewall("Firewall is disabled. (State = 0)"), .off)
    }
}
