import XCTest
@testable import Burrow

final class GitHubReleaseResolverTests: XCTestCase {
    private let json = """
    [{"tag_name":"v2.1.0","prerelease":false,"draft":false},
     {"tag_name":"v2.0.0","prerelease":false}]
    """

    func testLatestAndNewer() {
        XCTAssertEqual(GitHubReleaseResolver.latestTag(json), "2.1.0")
        XCTAssertEqual(GitHubReleaseResolver.newerVersion(json: json, installed: "2.0.0"), "2.1.0")
        XCTAssertNil(GitHubReleaseResolver.newerVersion(json: json, installed: "2.1.0"))
        XCTAssertNil(GitHubReleaseResolver.newerVersion(json: json, installed: "2.2.0"))
    }

    func testSkipsPrerelease() {
        let pre = """
        [{"tag_name":"v3.0.0-beta","prerelease":true},{"tag_name":"v2.5.0","prerelease":false}]
        """
        XCTAssertEqual(GitHubReleaseResolver.latestTag(pre), "2.5.0")
    }
}
