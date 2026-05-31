//
//  DBTests.swift
//  BurrowTests
//
//  Covers the SQLite-backed history store. Each test gets its own temp
//  DB so cases can't leak state into each other; the @testable import
//  reaches the internal `init(at:)` initializer that takes an explicit
//  path (production code uses `openDefault()` against Application
//  Support, which we don't want test runs touching).
//

import XCTest
@testable import Burrow

final class DBTests: XCTestCase {
    private var tempDir: URL!
    private var db: DB!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("burrow-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        db = try DB(at: tempDir.appendingPathComponent("burrow.db"))
    }

    override func tearDown() {
        db = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Roundtrip

    func testInsertAndFindLatest_returnsMostRecent() throws {
        try db.insert(prefix: "p", ts: 100, json: "{\"v\":1}")
        try db.insert(prefix: "p", ts: 200, json: "{\"v\":2}")
        try db.insert(prefix: "p", ts: 150, json: "{\"v\":1.5}")
        let row = try XCTUnwrap(db.findLatest(prefix: "p"))
        XCTAssertEqual(row.ts, 200)
        XCTAssertEqual(row.json, "{\"v\":2}")
    }

    func testFindLatest_returnsNilForUnknownPrefix() {
        XCTAssertNil(db.findLatest(prefix: "nope"))
    }

    /// Two writes at the same (prefix, ts) must last-write-wins, not
    /// duplicate or error. Sampler can fire twice in the same Mole
    /// `collected_at` second if a tick lags slightly.
    func testInsertSameKey_isLastWriteWins() throws {
        try db.insert(prefix: "p", ts: 100, json: "{\"v\":1}")
        try db.insert(prefix: "p", ts: 100, json: "{\"v\":99}")
        let rows = db.findRange(prefix: "p", since: 0, until: 1_000)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].json, "{\"v\":99}")
    }

    // MARK: - Range query

    func testFindRange_isInclusiveAndOrdered() throws {
        for i in 0..<10 {
            try db.insert(prefix: "p", ts: 100 + i, json: "{\"v\":\(i)}")
        }
        let mid = db.findRange(prefix: "p", since: 102, until: 105)
        XCTAssertEqual(mid.map { $0.ts }, [102, 103, 104, 105])
    }

    /// Cross-prefix isolation: a query for "a" must not return "b" rows
    /// even if their timestamps overlap. PK is (prefix, ts) so this is a
    /// correctness floor, not a perf one.
    func testFindRange_isIsolatedByPrefix() throws {
        try db.insert(prefix: "a", ts: 100, json: "{}")
        try db.insert(prefix: "b", ts: 100, json: "{}")
        let aOnly = db.findRange(prefix: "a", since: 0, until: 1_000)
        XCTAssertEqual(aOnly.count, 1)
    }

    // MARK: - Stride-sampled query

    /// Bound the returned count at `maxPoints`, evenly across the window.
    /// We don't assert exact stride — SQL's GROUP BY can produce one
    /// extra bucket at the edge — just that we land in the right
    /// ballpark and the rows are monotonic.
    func testFindRangeSampled_boundedByMaxPoints() throws {
        for i in 0..<1_000 {
            try db.insert(prefix: "p", ts: i, json: "{\"v\":\(i)}")
        }
        let sampled = db.findRangeSampled(prefix: "p", since: 0, until: 999, maxPoints: 100)
        XCTAssertLessThanOrEqual(sampled.count, 110, "should be near 100, not full 1000")
        XCTAssertGreaterThan(sampled.count, 50, "sampler shouldn't collapse data to a single row")
        // Monotone increasing in ts.
        for i in 1..<sampled.count {
            XCTAssertLessThan(sampled[i - 1].ts, sampled[i].ts)
        }
    }

    func testFindRangeSampled_sparseDataReturnsAllRows() throws {
        try db.insert(prefix: "p", ts: 10, json: "{}")
        try db.insert(prefix: "p", ts: 500, json: "{}")
        try db.insert(prefix: "p", ts: 990, json: "{}")
        let sampled = db.findRangeSampled(prefix: "p", since: 0, until: 1_000, maxPoints: 720)
        XCTAssertEqual(sampled.map { $0.ts }, [10, 500, 990])
    }

    // MARK: - listPrefixes

    func testListPrefixes_returnsDistinctSorted() throws {
        try db.insert(prefix: "b", ts: 1, json: "{}")
        try db.insert(prefix: "a", ts: 1, json: "{}")
        try db.insert(prefix: "a", ts: 2, json: "{}")
        try db.insert(prefix: "c", ts: 1, json: "{}")
        XCTAssertEqual(db.listPrefixes(), ["a", "b", "c"])
    }

    // MARK: - Prune

    func testPruneOlderThan_deletesPastCutoff() throws {
        try db.insert(prefix: "p", ts: 100, json: "{}")
        try db.insert(prefix: "p", ts: 200, json: "{}")
        try db.insert(prefix: "p", ts: 300, json: "{}")
        let deleted = try db.pruneOlderThan(250)
        XCTAssertEqual(deleted, 2)
        let surviving = db.findRange(prefix: "p", since: 0, until: 1_000)
        XCTAssertEqual(surviving.map { $0.ts }, [300])
    }

    func testPruneOlderThan_zeroWhenAllRowsFresh() throws {
        try db.insert(prefix: "p", ts: 500, json: "{}")
        let deleted = try db.pruneOlderThan(100)
        XCTAssertEqual(deleted, 0)
    }
}
