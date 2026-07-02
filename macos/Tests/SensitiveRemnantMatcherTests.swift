import XCTest
@testable import Burrow

final class SensitiveRemnantMatcherTests: XCTestCase {
    func testFlagsCredentials() {
        XCTAssertTrue(SensitiveRemnantMatcher.isSensitive("/Users/x/Library/Keychains/login.keychain-db"))
        XCTAssertTrue(SensitiveRemnantMatcher.isSensitive("/Users/x/.ssh/id_rsa"))
        XCTAssertTrue(SensitiveRemnantMatcher.isSensitive("/Users/x/.aws/credentials"))
    }

    func testOrdinaryCacheNotFlagged() {
        XCTAssertFalse(SensitiveRemnantMatcher.isSensitive("/Users/x/Library/Caches/com.foo/Cache.db"))
        XCTAssertFalse(SensitiveRemnantMatcher.isSensitive("/Applications/Foo.app"))
    }
}
