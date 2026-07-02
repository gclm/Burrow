import XCTest
@testable import Burrow

final class ConnectionHistoryTests: XCTestCase {
    private func e(_ ssid: String?, _ reason: String, _ t: TimeInterval) -> ConnectionHistory.Entry {
        ConnectionHistory.Entry(at: Date(timeIntervalSince1970: t), ssid: ssid, reason: reason)
    }

    func testAppend_newestFirst() {
        var list: [ConnectionHistory.Entry] = []
        list = ConnectionHistory.appended(list, e("Home", "ok", 1))
        list = ConnectionHistory.appended(list, e("Cafe", "captivePortal", 2))
        XCTAssertEqual(list.map(\.ssid), ["Cafe", "Home"])
    }

    func testAppend_collapsesConsecutiveRepeat() {
        var list: [ConnectionHistory.Entry] = []
        list = ConnectionHistory.appended(list, e("Home", "ok", 1))
        list = ConnectionHistory.appended(list, e("Home", "ok", 5))
        XCTAssertEqual(list.count, 1, "same ssid+reason collapses")
        XCTAssertEqual(list.first?.at, Date(timeIntervalSince1970: 5), "timestamp refreshed")
    }

    func testAppend_doesNotCollapseWhenReasonChanges() {
        var list: [ConnectionHistory.Entry] = []
        list = ConnectionHistory.appended(list, e("Home", "ok", 1))
        list = ConnectionHistory.appended(list, e("Home", "noInternet", 2))
        XCTAssertEqual(list.count, 2)
    }

    func testAppend_capsAtMaximum() {
        var list: [ConnectionHistory.Entry] = []
        for i in 0..<(ConnectionHistory.cap + 10) {
            list = ConnectionHistory.appended(list, e("net\(i)", "ok", Double(i)))
        }
        XCTAssertEqual(list.count, ConnectionHistory.cap)
        XCTAssertEqual(list.first?.ssid, "net\(ConnectionHistory.cap + 9)", "newest kept")
    }
}
