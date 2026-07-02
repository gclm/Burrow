import XCTest
@testable import Burrow

final class UninstallPlanTests: XCTestCase {
    func testDataOnlyKeepsApp() {
        let paths = ["/Applications/Foo.app",
                     "/Users/x/Library/Caches/com.foo",
                     "/Users/x/Library/Preferences/com.foo.plist"]
        XCTAssertEqual(UninstallPlan.dataOnly(paths: paths), [paths[1], paths[2]])
    }

    func testInputMethod() {
        XCTAssertTrue(UninstallPlan.isInputMethod("/Library/Input Methods/WeChat.app"))
        XCTAssertFalse(UninstallPlan.isInputMethod("/Applications/Foo.app"))
    }

    func testAliasMatch() {
        XCTAssertTrue(UninstallPlan.matches(query: "studio", name: "Visual Studio Code", bundleID: "com.microsoft.VSCode", aliases: []))
        XCTAssertTrue(UninstallPlan.matches(query: "vscode", name: "Visual Studio Code", bundleID: "com.microsoft.VSCode", aliases: ["vscode"]))
        XCTAssertFalse(UninstallPlan.matches(query: "xyz", name: "Foo", bundleID: "com.foo", aliases: []))
        XCTAssertTrue(UninstallPlan.matches(query: "  ", name: "Foo", bundleID: "x", aliases: []))
    }
}
