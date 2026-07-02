import XCTest
@testable import Burrow

final class ProcessOriginTests: XCTestCase {
    func testShellAncestor() {
        let t: [Int: ProcessOrigin.Info] = [
            500: .init(name: "node", ppid: 400),
            400: .init(name: "zsh", ppid: 300),
            300: .init(name: "login", ppid: 1),
            1: .init(name: "launchd", ppid: 0),
        ]
        XCTAssertEqual(ProcessOrigin.classify(pid: 500, table: t), .shell("zsh"))
    }

    func testSSHAncestor() {
        let t: [Int: ProcessOrigin.Info] = [
            700: .init(name: "scp", ppid: 650),
            650: .init(name: "sshd", ppid: 1),
        ]
        XCTAssertEqual(ProcessOrigin.classify(pid: 700, table: t), .ssh)
    }

    func testLoginDefault() {
        let t: [Int: ProcessOrigin.Info] = [
            800: .init(name: "Safari", ppid: 1),
            1: .init(name: "launchd", ppid: 0),
        ]
        XCTAssertEqual(ProcessOrigin.classify(pid: 800, table: t), .login)
    }
}
