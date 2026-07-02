import XCTest
@testable import Burrow

final class SpeedTestTests: XCTestCase {
    func testThroughputAndJitter() {
        // 1,250,000 bytes/s × 8 / 1e6 = 10 Mbps
        let r = SpeedTest.aggregate(byteSamples: [1_250_000, 1_250_000], latenciesMs: [10, 12, 11])
        XCTAssertEqual(r.mbps, 10, accuracy: 0.01)
        XCTAssertEqual(r.lossPercent, 0)
        XCTAssertGreaterThan(r.jitterMs, 0)
    }

    func testPacketLoss() {
        let r = SpeedTest.aggregate(byteSamples: [], latenciesMs: [10, nil, 12, nil])
        XCTAssertEqual(r.lossPercent, 50)   // 2 of 4 lost
    }
}
